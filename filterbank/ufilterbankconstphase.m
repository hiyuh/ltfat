function [c,newphase,usedmask,tgrad,fgrad]=ufilterbankconstphase(s,a,tfr,fc,varargin)
%% Old help -> CONSTRUCTPHASEREAL  Construct phase for DGTREAL
%   Usage:  c=constructphasereal(s,g,a,M);
%           c=constructphasereal(s,g,a,M,tol);
%           c=constructphasereal(c,g,a,M,tol,mask);
%           c=constructphasereal(c,g,a,M,tol,mask,usephase);
%           [c,newphase,usedmask,tgrad,fgrad] = constructphasereal(...);
%
%   Input parameters:
%         s        : Initial coefficients.
%         g        : Analysis Gabor window.
%         a        : Hop factor.
%         M        : Number of channels.
%         tol      : Relative tolerance.
%         mask     : Mask for selecting known phase.
%         usephase : Explicit known phase.
%   Output parameters:
%         c        : Coefficients with the constructed phase.
%         newphase : Just the (unwrapped) phase.
%         usedmask : Mask for selecting coefficients with the new phase.
%         tgrad    : Relative time phase derivative.
%         fgrad    : Relative frequency phase derivative.
%
%   `constructphasereal(s,g,a,M)` will construct a suitable phase for the 
%   positive valued coefficients *s*.
%
%   If *s* contains the absolute values of the Gabor coefficients of a signal
%   obtained using the window *g*, time-shift *a* and number of channels 
%   *M*, i.e.:
%
%     c=dgtreal(f,g,a,M);
%     s=abs(c);
%
%   then `constuctphasereal(s,g,a,M)` will attempt to reconstruct *c*.
%
%   The window *g* must be Gaussian, i.e. *g* must have the value `'gauss'`
%   or be a cell array `{'gauss',...}`.
%
%   `constructphasereal(s,g,a,M,tol)` does as above, but sets the phase of
%   coefficients less than *tol* to random values.
%   By default, *tol* has the value 1e-10. 
%
%   `constructphasereal(c,g,a,M,tol,mask)` accepts real or complex valued
%   *c* and real valued *mask* of the same size. Values in *mask* which can
%   be converted to logical true (anything other than 0) determine
%   coefficients with known phase which is used in the output. Only the
%   phase of remaining coefficients (for which mask==0) is computed.
%
%   `constructphasereal(c,g,a,M,tol,mask,usephase)` does the same as before
%   but uses the known phase values from *usephase* rather than from *c*.
%
%   In addition, *tol* can be a vector containing decreasing values. In 
%   that case, the algorithm is run `numel(tol)` times, initialized with
%   the result from the previous step in the 2nd and the further steps.
%
%   Further, the function accepts the following flags:
%
%      'freqinv'  The constructed phase complies with the frequency
%                 invariant phase convention such that it can be directly
%                 used in |idgtreal|.
%                 This is the default.
%
%      'timeinv'  The constructed phase complies with the time-invariant
%                 phase convention. The same flag must be used in the other
%                 functions e.g. |idgtreal|
%
%   This function requires a computational subroutine that is only
%   available in C. Use |ltfatmex| to compile it.
%
%   See also:  dgtreal, gabphasegrad, ltfatmex
%
%   References: ltfatnote040
%

% AUTHOR: Peter L. Søndergaard, Zdenek Prusa

thismfilename = upper(mfilename);
complainif_notposint(a,'a',thismfilename);


definput.keyvals.tol=[1e-1,1e-10];
definput.keyvals.mask=[];
definput.keyvals.usephase=[];
definput.flags.real={'real','complex'};
[flags,~,tol,mask,usephase]=ltfatarghelper({'tol','mask','usephase'},definput,varargin);

if ~isnumeric(s) 
    error('%s: *s* must be numeric.',thismfilename);
end

if ~isempty(usephase) && isempty(mask)
    error('%s: Both mask and usephase must be used at the same time.',...
          upper(mfilename));
end

if isempty(mask) 
    if ~isreal(s) || any(s(:)<0)
        error('%s: *s* must be real and positive when no mask is used.',...
              thismfilename);
    end
else 
    if any(size(mask) ~= size(s)) || ~isreal(mask)
        error(['%s: s and mask must have the same size and mask must',...
               ' be real.'],thismfilename)
    end
    % Sanitize mask (anything other than 0 is true)
    mask = cast(mask,'double');
    mask(mask~=0) = 1;
end

if ~isempty(usephase)
    if any(size(mask) ~= size(s)) || ~isreal(usephase)
        error(['%s: s and usephase must have the same size and usephase must',...
               ' be real.'],thismfilename)        
    end
else
    usephase = angle(s);
end

if ~isnumeric(tol) || ~isequal(tol,sort(tol,'descend'))
    error(['%s: *tol* must be a scalar or a vector sorted in a ',...
           'descending manner.'],thismfilename);
end


[N,M,W] = size(s);
L=N*a;

% Prepare differences of center frequencies [given in normalized frequency]
% and dilation factors (square root of the time-frequency ratio)
cfreqdiff = diff(fc);
sqtfr = sqrt(tfr);
sqtfrdiff = diff(sqtfr);

% Filterbankphasegrad does not support phasederivatives from absolute
% values
abss = abs(s);
logs=log(abss+realmin);
tt=-11;
logs(logs<max(logs(:))+tt)=tt;

difforder = 2;
% Obtain the (relative) phase difference in frequency direction by taking
% the time derivative of the log magnitude and weighting it by the
% time-frequency ratio of the appropriate filter.
% ! Note: This disregards the 'quadratic' factor in the equation for the 
% phase derivative !
fgrad = pderiv(logs,1,difforder)/(2*pi);
for kk = 1:M
    fgrad(:,kk,:) = tfr(kk).*fgrad(:,kk,:);
end

    
% Obtain the (relative) phase difference in time direction using the
% frequency derivative of the log magnitude. The result is the mean of
% estimates obtained from 'above' and 'below', appropriately weighted by
% the channel distance and the inverse time-frequency ratio of the
% appropriate filter.
% ! Note: We consider the term depending on the time-frequency ratio 
% difference, but again disregard the 'quadratic' factor. !
tgrad = zeros(size(s));
if flags.do_real
    logsdiff = diff(logs,1,2);
    for kk = 2:M-1
        tgrad(:,kk,:) = (logsdiff(:,kk,:) + 2*sqtfrdiff(kk)./sqtfr(kk)./pi)./cfreqdiff(kk) + ...
                        (logsdiff(:,kk-1,:) + 2*sqtfrdiff(kk-1)./sqtfr(kk)./pi)./cfreqdiff(kk-1);
        tgrad(:,kk,:) = tgrad(:,kk,:)./tfr(kk)./(pi*L);
    end
    % For first and last channel, use a 1st order difference scheme as they
    % are not considered to be adjacent.
    tgrad(:,1,:) = 2*(logsdiff(:,1,:) + 2*sqtfrdiff(1)./sqtfr(1)./pi)./cfreqdiff(1);
    tgrad(:,1,:) = tgrad(:,1,:)./tfr(1)./(pi*L);
    tgrad(:,M,:) = 2*(logsdiff(:,M-1,:) + 2*sqtfrdiff(M-1)./sqtfr(M)./pi)./cfreqdiff(1);
    tgrad(:,M,:) = tgrad(:,M,:)./tfr(M)./(pi*L);
    % Fix the first and last rows .. the
    % borders are symmetric so the centered difference is 0
    %tgrad(:,1,:) = 0;
    %tgrad(:,M,:) = 0;
else
    logsdiff = diff([logs(:,M,:);logs;logs(:,1,:)],1,2); 
    for kk = 1:M
        tgrad(:,kk,:) = (logsdiff(:,kk+1,:) + 2*sqtfrdiff(kk+1)./sqtfr(kk)./pi)./cfreqdiff(kk) + ...
                        (logsdiff(:,kk,:) + 2*sqtfrdiff(kk)./sqtfr(kk)./pi)./cfreqdiff(kk-1);
        tgrad(:,kk,:) = tgrad(:,kk,:)./tfr(kk)./(pi*L);
    end
end

%% DO the heap integration
absthr = max(abss(:))*tol;
if isempty(mask)
    usedmask = zeros(size(s));
else
    usedmask = mask;
end

if isempty(mask)
    % Build the phase (calling a MEX file)
    newphase=comp_ufilterbankheapint(abss,tgrad,fgrad,fc,a,flags.do_real,tol(1),1);
    % Set phase of the coefficients below tol to random values
    bigenoughidx = abss>absthr(1);
    usedmask(bigenoughidx) = 1;
else
    newphase=comp_ufilterbankmaskedheapint(abss,tgrad,fgrad,fc,mask,a,flags.do_real,tol(1),1,...
                                usephase);
    % Set phase of small coefficient to random values
    % but just in the missing part
    % Find all small coefficients in the unknown phase area
    missingidx = find(usedmask==0);
    bigenoughidx = abss(missingidx)>absthr(1);
    usedmask(missingidx(bigenoughidx)) = 1;
end

% Do further tol
for ii=2:numel(tol)
    newphase=comp_ufilterbankmaskedheapint(abss,tgrad,fgrad,fc,usedmask,a,flags.do_real,tol(ii),1,...
                                newphase);
    missingidx = find(usedmask==0);
    bigenoughidx = abss(missingidx)>absthr(ii);
    usedmask(missingidx(bigenoughidx)) = 1;                  
end

% Convert the mask so it can be used directly for indexing
usedmask = logical(usedmask);
% Assign random values to coefficients below tolerance
zerono = numel(find(~usedmask));
newphase(~usedmask) = rand(zerono,1)*2*pi;

% Build the coefficients
c=abss.*exp(1i*newphase);