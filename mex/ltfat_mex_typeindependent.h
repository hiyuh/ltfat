#if defined(LTFAT_SINGLE) || defined(LTFAT_DOUBLE)
#include "ltfat_types.h"
#include "mex.h"
#include "fftw3.h"
#include <complex.h>


mxArray* LTFAT_NAME(mexSplit2combined)( const mxArray *parg);
mxArray* LTFAT_NAME(mexCombined2split)( const mxArray *parg);


mxArray* LTFAT_NAME(mexSplit2combined)( const mxArray *parg)
{
   if(mxIsCell(parg))
   {
      mxArray* tmpCell = mxCreateCellMatrix(mxGetM(parg), mxGetN(parg));
      for(unsigned int jj=0;jj<mxGetNumberOfElements(parg);jj++)
      {
         mxSetCell(tmpCell, (mwIndex) jj, LTFAT_NAME(mexSplit2combined)(mxGetCell(parg, jj)));
      }
      return tmpCell;
   }

   // just copy pointer if the element is not numeric
   if(!mxIsNumeric(parg))
   {
      return (mxArray*)parg;
   }

   mwIndex ndim = mxGetNumberOfDimensions(parg);
   const mwSize *dims = mxGetDimensions(parg);

   mxArray* out = ltfatCreateNdimArray(ndim,dims,LTFAT_MX_CLASSID,mxCOMPLEX);
   mwSize L = mxGetNumberOfElements(parg);

   LTFAT_COMPLEXH* outc = (LTFAT_COMPLEXH*) mxGetData(out);

   LTFAT_REAL *i_r= (LTFAT_REAL*) mxGetPr(parg);

   if (mxIsComplex(parg))
   {
      LTFAT_REAL *i_i= (LTFAT_REAL*) mxGetPi(parg);

      for (mwIndex ii=0;ii<L; ii++)
      {
         outc[ii] = i_r[ii] + i_i[ii]*I;
      }
   }
   else
   {
      /* No imaginary part */
      for (mwIndex ii=0;ii<L; ii++)
      {
	    outc[ii] = i_r[ii];
      }
   }
   return out;
}

mxArray* LTFAT_NAME(mexCombined2split)( const mxArray *parg)
{
   if(mxIsCell(parg))
   {
      mxArray* tmpCell = mxCreateCellMatrix(mxGetM(parg), mxGetN(parg));
      for(unsigned int jj=0;jj<mxGetNumberOfElements(parg);jj++)
      {
         mxSetCell(tmpCell, (mwIndex) jj, LTFAT_NAME(mexCombined2split)(mxGetCell(parg, jj)));
      }
      return tmpCell;
   }

   // just copy pointer if the element is not numeric
   if(!mxIsNumeric(parg))
   {
      return (mxArray*)parg;
   }

   LTFAT_COMPLEXH *pargc = (LTFAT_COMPLEXH *) mxGetData(parg);
   mwIndex ndim = mxGetNumberOfDimensions(parg);
   const mwSize *dims = mxGetDimensions(parg);
   mxArray*out = mxCreateNumericArray(ndim,dims,LTFAT_MX_CLASSID,mxCOMPLEX);

   LTFAT_REAL *outr=(LTFAT_REAL *)mxGetPr(out);
   LTFAT_REAL *outi=(LTFAT_REAL *)mxGetPi(out);

   mwSize L = mxGetNumberOfElements(parg);

   for (mwIndex ii=0;ii<L; ii++)
   {
      outr[ii] = __real__ pargc[ii];
      outi[ii] = __imag__ pargc[ii];
   }
   return out;
}

#endif
