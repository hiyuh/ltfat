function [tc,relres,iter,frec,cd] = franalasso(F,f,lambda,varargin)
%FRANALASSO  Frame LASSO regression
%   Usage: [tc,xrec] = franalasso(F,f,lambda,C,tol,maxit)
%
%   Input parameters:
%       F        : Frame definition
%       f        : Input signal
%       lambda   : Regularization parameter, controls sparsity of the solution
%   Output parameters:
%       tc       : Thresholded coefficients
%       relres   : Vector of residuals.
%       iter     : Number of iterations done.  
%       frec     : Reconstructed signal
%
%   `franalasso(F,f,lambda)` solves the LASSO (or basis pursuit denoising)
%   regression problem for a general frame: minimize a functional of the
%   synthesis coefficients defined as the sum of half the $l^2$ norm of the
%   approximation error and the $l^1$ norm of the coefficient sequence, with
%   a penalization coefficient *lambda* such that
%
%   .. argmin lambda||c||_1 + 1/2||Fc - f||_2^2
%
%   .. math:: \text{argmin}_c \ \lambda ||c||_1 +  \frac{1}{2}||Fc - f||_2^2
%
%   The solution is obtained via an iterative procedure, called Landweber
%   iteration, involving iterative soft thresholdings.
%  
%   `[tc,relres,iter] = franalasso(...)` return thes residuals *relres* in a vector
%   and the number of iteration steps done *iter*.
%
%   `[tc,relres,iter,frec,cd] = franalasso(...)` returns the reconstructed
%   signal from the coefficients, *frec* and coefficients *cd* obtained by
%   analysing using the canonical dual system. 
%   Note that this requires additional computations.
%
%   The relationship between the output coefficients is given by ::
%
%     frec = frsyn(F,tc);
%
%   The function takes the following optional parameters at the end of
%   the line of input arguments:
%
%     'C',cval   Landweber iteration parameter: must be larger than
%                square of upper frame bound. Default value is the upper
%                frame bound.
%
%     'tol',tol  Stopping criterion: minimum relative difference between
%                norms in two consecutive iterations. Default value is
%                1e-2.
%
%     'maxit',maxit
%                Stopping criterion: maximal number of iterations to do.
%                Default value is 100.
%
%     'print'    Display the progress.
%
%     'quiet'    Don't print anything, this is the default.
%
%     'printstep',p
%                If 'print' is specified, then print every p'th
%                iteration. Default value is 10;
%
%   The parameters *C*, *itermax* and *tol* may also be specified on the
%   command line in that order: `franalasso(F,x,lambda,C,tol,maxit)`.
%
%   **Note**: If you do not specify *C*, it will be obtained as the upper
%   framebound. Depending on the structure of the frame, this can be an
%   expensive operation.
%
%   Examples:
%   ---------
%
%   The following example shows how |franalasso| produces a sparse
%   representation of a test signal *greasy*:::
%
%      f = greasy;
%      % Gabor frame with redundancy 8
%      F = frame('dgtreal','gauss',64,512);
%      % Choosing lambda (weight of the sparse regularization param.)
%      lambda = 0.1;
%      % Solve the basis pursuit problem
%      [c,~,~,frec,cd] = franalasso(F,f,lambda);
%      % Plot sparse coefficients
%      figure(1);
%      plotframe(F,c,'dynrange',50);
%
%      % Plot coefficients obtained by applying an analysis operator of a
%      % dual Gabor system to f
%      figure(2);
%      plotframe(F,cd,'dynrange',50);
%
%      % Check the (NON-ZERO) reconstruction error .
%      % frec is obtained by applying the synthesis operator of frame F
%      % to sparse coefficients c.
%      norm(f-frec)
%
%      % Compare decay of coefficients sorted by absolute values
%      % (compressibility of coefficients)
%      figure(3);
%      semilogx([sort(abs(c),'descend')/max(abs(c)),...
%      sort(abs(cd),'descend')/max(abs(cd))]);
%      legend({'sparsified coefficients','dual system coefficients'});
%  
%   See also: frame, frsyn, framebounds, franabp, franagrouplasso
%
%   References: dademo04 beck09

%   AUTHOR : Bruno Torresani.  
%   TESTING: OK

%   XXX Removed Remark: When the frame is an orthonormal basis, the solution
%   is obtained by soft thresholding of the basis coefficients, with
%   threshold lambda.  When the frame is a union of orthonormal bases, the
%   solution is obtained by applying soft thresholding cyclically on the
%   basis coefficients (BCR algorithm)
%

complainif_notenoughargs(nargin,2,'FRANALASSO');
complainif_notvalidframeobj(F,'FRANALASSO');

if sum(size(f)>1)>1
  error('%s: Too many input channels.',upper(mfilename));    
end


% Define initial value for flags and key/value pairs.
definput.keyvals.C=[];
definput.keyvals.tol=1e-2;
definput.keyvals.maxit=100;
definput.keyvals.printstep=10;
definput.flags.print={'print','quiet'};
definput.flags.algorithm={'fista','ista'};
definput.flags.startphase={'zero','rand','int'};

[flags,kv]=ltfatarghelper({'C','tol','maxit'},definput,varargin);


% Accelerate frame, we will need it repeatedly
Ls = size(f,1);
F=frameaccel(F,Ls);
L=F.L;

% Use the upper framebound as C
if isempty(kv.C)
  [~,kv.C] = framebounds(F,L);
end;

% Initialization of thresholded coefficients
% frana is used instead of F.frana to get the correct zero padding of f
c0 = frana(F,f);

% Various parameter initializations
threshold = lambda/kv.C;

tc0 = c0;
relres = 1e16;
iter = 0;

if flags.do_ista
   % Main loop
   while ((iter < kv.maxit)&&(relres >= kv.tol))
       tc = c0 - F.frana(F.frsyn(tc0));
       tc = tc0 + tc/kv.C;
       tc = thresh(tc,threshold,'soft');
       relres = norm(tc(:)-tc0(:))/norm(tc0(:));
       tc0 = tc;
       iter = iter + 1;
       if flags.do_print
         if mod(iter,kv.printstep)==0        
           fprintf('Iteration %d: relative error = %f\n',iter,relres);
         end;
       end;
   end
elseif flags.do_fista
   tz0 = c0;
   tau0 = 1;
   % Main loop
   while ((iter < kv.maxit)&&(relres >= kv.tol))
       tc = c0 - F.frana(F.frsyn(tz0));
       tc = tz0 + tc/kv.C;
       tc = thresh(tc,threshold,'soft');
       
       tau = 1/2*(1+sqrt(1+4*tau0^2));
       tz0 = tc + (tau0-1)/tau*(tc-tc0);
       relres = norm(tc(:)-tc0(:))/norm(tc0(:));
       tc0 = tc;
       tau0 = tau;
       iter = iter + 1;
       if flags.do_print
         if mod(iter,kv.printstep)==0        
           fprintf('Iteration %d: relative error = %f\n',iter,relres);
         end;
       end;
   end   
   
end

% Optional reconstruction
if nargout>3
   frec = postpad(F.frsyn(tc),Ls);
end;

% Calculate coefficients using the canonical dual system
% May be conviniently used for comparison
if nargout>4
  try  
     Fd = framedual(F);
     cd = frana(Fd,f);
  catch
     warning(sprintf(['%s: Dual frame is not available. Using franaiter'],...
                     upper(mfilename)));
     cd = franaiter(F,f);
  end
end;


