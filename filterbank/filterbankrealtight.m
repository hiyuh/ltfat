function gtout=filterbankrealtight(g,a,L)
%FILTERBANKREALTIGHT  Tight filters of filterbank for real signals only 
%   Usage:  gt=filterbankrealtight(g,a,L);
%           gt=filterbankrealtight(g,a);
%
%   `filterabankrealtight(g,a,L)` computes the canonical tight filters of 
%   *g* for a channel subsampling rate of *a* (hop-size) and a system 
%   length *L*. *L* must be compatible with subsampling rate *a* as 
%   `L==filterbanklength(L,a)`. The tight filters work only for real-valued
%   signals. Use this function on the common construction where the filters
%   in *g* only covers the positive frequencies.
%
%   `filterabankrealtight(g,a)` does the same, but the filters must be FIR
%   filters, as the transform length is unspecified. *L* will be set to 
%   next suitable length equal or bigger than the longest impulse response.  
%
%   The format of the filters *g* are described in the help of |filterbank|.
%
%   REMARK: The resulting system is tight for length *L*. In some cases, 
%   using tight system calculated for shorter *L* might work but check the
%   reconstruction error.
%
%   See also: filterbank, ufilterbank, ifilterbank

complainif_notenoughargs(nargin,2,'FILTERBANKREALTIGHT');

if nargin<3
   L = [];
end

if isempty(L)
    if ~all(cellfun(@(gEl) isfield(gEl,'H'),g))
        % All filters are FIR, therefore filterbankwin can be called without L
        [~,info]=filterbankwin(g,a);
        if ~info.isfir
            % Just a sanity check
            error('%s: Internal error. Filterbank should be FIR. ',...
                  upper(mfilename));
        end
        % Use next suitable length
        L = filterbanklength(info.longestfilter,a);
    else
        error(['%s: L must be specified when working with filters defined ',...
           ' in frequency.'], upper(mfilename));
   end
end

[g,info]=filterbankwin(g,a,L,'normal');
M=info.M;

if L~=filterbanklength(L,a)
     error(['%s: Specified length L is incompatible with the length of ' ...
            'the time shifts.'],upper(mfilename));
end;

% Prioritize painless over uniform algorithm
if info.isuniform && info.ispainless
    info.isuniform = 0;
end

if info.isuniform
  % Uniform filterbank, use polyphase representation
  if isempty(L)
      error('%s: You need to specify L.',upper(mfilename));
  end;

  a=a(1);
  
  % G1 is done this way just so that we can determine the data type.
  G1=comp_transferfunction(g{1},L);
  thisclass=assert_classname(G1);
  G=zeros(L,M,thisclass);
  G(:,1)=G1;
  for ii=2:M
    G(:,ii)=comp_transferfunction(g{ii},L);
  end;
  
  N=L/a;

  gt=zeros(M,N,thisclass);
  
  for w=0:N-1
    idx_a = mod(w-(0:a-1)*N,L)+1;
    idx_b = mod((0:a-1)*N-w,L)+1;
    Ha = G(idx_a,:);
    Hb = conj(G(idx_b,:));
    
    Ha=sqrtm(Ha*Ha'+Hb*Hb')\Ha;
    
    gt(:,idx_a)=Ha.';
  end;
  % gt was created transposed because the indexing gt(:,idx_a)
  % is much faster than gt(idx_a,:)
  gt =  gt.';
  
  gt=ifft(gt)*sqrt(a);
  
  % Matrix cols to cell elements + cast
  gtout = cellfun(@(gtEl) cast(gtEl,thisclass), num2cell(gt,1),...
                  'UniformOutput',0);
  
else
        
    if info.ispainless
        if isempty(L)
            error('%s: You need to specify L.',upper(mfilename));
        end;
        
        gtout = comp_painlessfilterbank(g,info.a,L,'tight',1);

    else
        error(['%s: The canonical dual frame of this system is not a ' ...
               'filterbank. You must call an iterative ' ...
               'method to perform the desired inverstion. Please see ' ...
               'FRANAITER or FRSYNITER.'],upper(mfilename));        

    end;
  
end;
