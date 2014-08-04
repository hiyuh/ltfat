/*
 * ltfatresample.h
 *
 * This is an attempt for a self-containded arbitrary factor resampling API
 * working with streams of blocks of arbitrary lengths.
 *
 * How does it work?
 *
 * The approach could probably be called hybrid. A simple polynomial
 * interpolation is used when doing upsampling (ratio > 1). An anti-aliasing
 * filter is used when doing subsampling (ratio<0.95) followed by a polynomial
 * interpolation. The antialiasing IIR filter is designed such that the overall
 * frequency response have almost linear phase freq. response (less so close to
 * the passband-edge frequency) and negligible rippling in the passband (one over
 * stopband attenuation).
 *
 * I opted for IIR filters over FIR because of two reasons:
 *
 * 1) I did not want any external dependency, which basically rules out
 *    all FIR filters already, since they require FFT implementation in
 *    order to be fast.
 * 2) IIR filters used require only a handfull of their coefficients to be
 *    stored (see "filtcoefs.h"). This is in sharp contrast with e.g. long
 *    sinc kernel techniques which require storing thousands of coefficients.
 *    See e.g. libsamplerate
 *
 * The IIR filter design used is taken from chapter V in this book:
 *
 *    Milic L.: Multirate Filtering for Digital Signal Processing:
 *    MATLAB Applications, 2008, ISBN:1605661783
 *
 * The filters are called Elliptic Minimal Q-Factors (EMQF). They are derived
 * from a prototype halfband lowpass IIR filter consisting of parallel
 * combination of two all pass filters. Both allpass filters consist of
 * serially connected 2nd order allpass filters. Using a simple procedure
 * described in
 * Chapter: IIR STRUCTURES WITH TWO ALL-PASS SUBFILTERS: APPLICATIONS
 * OF EMQF FILTERS,
 * the prototype filter passband edge frequency can be changed while keeping (almost)
 * the same structure (two branches, chains of allpass filters).
 *
 * The coefficients defining the prototype half-band filter are stored
 * in "filtcoefs.h". The file is generated by a Matlab script "genfiltcoefs.m".
 * The header file defines a double array "EMQFcoefs" of length EMQFCOEFLEN
 * defined as a macro in the same file. The coefficients are the beta
 * coefficients from (5.36) from the book.
 *
 * The passband edge frequency is set to FPADJ*fs_target/2. FPADJ macro is set in
 * "config.h".
 *
 *
 * Copyright (C) 2014 Zdenek Prusa <prusa@users.sourceforge.net>.
 * This file is part of LTFAT http://ltfat.sourceforge.net
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifndef _LTFATRESAMPLE_H
#define _LTFATRESAMPLE_H

/* malloc, calloc, free etc. */
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <math.h>
#include <assert.h>

/* The following defines SAMPLE, FADJ */
#include "config.h"

/* Just to be on the safe side, define all mandatory compile time params. */
#ifndef RESAMPLING_TYPE
#   define RESAMPLING_TYPE BSPLINE
#endif

#ifndef FPADJ
#  define FPADJ 0.92
#endif

/* Here we include a generated file containing prototype filters */
/* We use elliptic minimal Q-factors IIR filters (EMQF) from
 * Multirate Filtering for DSP: MATLAB Applications by Ljiljana Milic, chapter V
 * */
#include "filtcoefs.h"

#if !defined(EMQFCOEFLEN) || EMQFCOEFLEN<1
#  error Undefined EMQFCOEFLEN. Check filtcoefs.h
#endif

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif


/*
 *  POLYNOMIAL INTERPOLATION
 *
 *
 * */

/* Interpolation type */
typedef enum
{
   LINEAR = 0, /* Mere lin. intp. */
   LAGRANGE,   /* 6point Lagrange interpolator */
   BSPLINE     /* 6point B-spline interpolator */
} resample_type;

/* Error code to check */
typedef enum
{
   RESAMPLE_OK = 0,
   RESAMPLE_NULLPOINTER,
   RESAMPLE_OVERFLOW,
   RESAMPLE_UNDERFLOW
} resample_error;

typedef struct resample_plan_struct *resample_plan;




/**********************************************
 **************  Public API  ******************
 **********************************************/


/*! \brief Initialize resampling plan
 *
 *  @param restype polynomial interpolation type
 *  @param ratio sampling rate change ratio fs_target/fs_source
 *  @see resample_execute()
 *  @see resampe_done()
 *  @return An opaque pointer to a struct holding all the resampling parameters
 */
resample_plan
resample_init(const resample_type restype,
              const double ratio);


/*! \brief Reset resampling plan
 *
 *  @param restype polynomial interpolation type
 */
void
resample_reset(const resample_plan rp);

/*! \brief Execute resampling
 *
 *  in might get overwritten by a low-pass filtered version
 *
 *  Either Lin or Lout should be fixed to a required value and the other
 *  one obtained by resample_nextoutlen, resample_nextinlen respectivelly.
 *
 *  Note: When using Lout fixed, the routine might internally store more values. 
 *
 *  The function returns RESAMPLE_OVERFLOW if it could have produce more samples, but
 *  Lout (plus internal storage buffer) is too small. The overflowing samples are
 *  discarded.
 *
 *  The function returns RESAMPLE_UNDERFLOW if the number of input samples is not
 *  enough to calculate all required output samples. The remaining output samples are set 
 *  to zeros.
 *
 *  If one of the overflows occurs, the stream is reset to avoid problems in next
 *  iterations.
 *
 *  @param rp resampling plan
 *  @param in input array
 *  @param Lin input array length
 *  @param out output array
 *  @param Lout output array length
 *  @see resample_init()
 *  @see resampe_done()
 *  @return error code
 */
resample_error
resample_execute(const resample_plan rp,
                 SAMPLE* in, const size_t Lin,
                 SAMPLE* out, const size_t Lout);

/*! \brief Get next output array length
 *
 *  The number of output samples can vary. Internally, rp stores a sample
 *  counter which together with Lin determine length of output array next
 *  time resample_execute is called.
 *
 *  Use when input array length is fixed.
 *
 *  @param rp resampling plan
 *  @param Lin input array length
 *  @see resample_execute()
 *  @return next output array length
 */
size_t
resample_nextoutlen(const resample_plan rp, size_t Lin);

/*! \brief Get next input array length
 *
 *  Complementary to resample_nextoutlen. 
 *
 *  Use to get "compatible" input buffer length when Lout is required
 *
 */
size_t
resample_nextinlen(const resample_plan rp, size_t Lout);

/*! \brief Move the internal sample counter
 *
 *  @param rp resampling plan
 *  @param Lin input array length
 */
void
resample_advanceby(const resample_plan rp, const size_t Lin, const size_t Lout);

/*! Free all resources
 *
 * @param ef pointer to an opaque pointer
 */
void
resample_done(resample_plan *rp);


/**********************************************
 ************ End of public API  **************
 **********************************************/

/*
 *  Functions doing the actual resampling
 *
 */

resample_error
resample_execute_polynomial(const resample_plan rp,
                            const SAMPLE* in, const size_t Lin,
                            SAMPLE* out, const size_t Lout);

/*
 *  Functions generating one sample according to the polynomial
 *  interpolation technique.
 *  Function prototype is SAMPLE fcn(const double,const SAMPLE*)
 */
SAMPLE
lagrange_interp(const double x, const SAMPLE *yin);

SAMPLE
bspline_interp(const double x, const SAMPLE *yin);

SAMPLE
linear_interp(const double x, const SAMPLE *yin);

/**********************************************
 ************   EMQF   filters   **************
 **********************************************/


/* Struct for holding EMQF filter */
typedef struct EMQFfilters_struct *EMQFfilters;

/*! \brief Initialize EMQF filter structure
 *
 *  fc can be in range ]0,1[, otherwise the function returns NULL
 *
 *  @param fc passband edge frequency
 *  @return structure holding all partial filters (and their inner states)
 */
EMQFfilters
emqffilters_init(const double fc);

/*! \brief Do the filtering using the EMQF filter
 *
 *  @param ef filtering struct
 *  @param in input array
 *  @param Lin input/output array length
 *  @param out output array
 */

void
emqffilters_dofilter(EMQFfilters ef, const SAMPLE* in, const size_t Lin,
                     SAMPLE* out);

/*! Free all resources
 *
 *  @param ef pointer to an opaque pointer
 */
void
emqffilters_done(EMQFfilters* ef);

#endif
