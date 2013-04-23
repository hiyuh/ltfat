function f=comp_inonsepdgt_shear(coef,g,a,s0,s1,br)
%COMP_INONSEPDGT_SHEAR  Compute IDGT
%   Usage:  f=comp_inonsepdgt_shear(c,g,a,lt,phasetype);
%
%   Input parameters:
%         c        : Array of coefficients.
%         g        : Window function.
%         a        : Length of time shift.
%         s0,s1,br : shearfind parameters
%   Output parameters:
%         f     : Signal.

M=size(coef,1);
N=size(coef,2);
W=size(coef,3);

L=N*a;

b=L/M;
ar = a*b/br;
Mr = L/br;
Nr = L/ar;

ind = [ar 0; 0 br]*[kron((0:L/ar-1),ones(1,L/br));kron(ones(1,L/ar), ...
                                                  (0:L/br-1))];
phs = reshape(mod((s1*(ind(1,:)-s0*ind(2,:)).^2+s0*ind(2,:).^2)*(L+1) ...
                  -2*(s0 ~= 0)*ind(1,:).*ind(2,:),2*L),L/br,L/ar);    
phs = exp(-pi*1i*phs/L);

ind_final = [1 0;-s1 1]*[1 -s0;0 1]*ind;
ind_final = mod(ind_final,L);

if s1 ~= 0
    g = comp_pchirp(L,s1).*g;
end

if s0 == 0

    c_rect = zeros(Mr,Nr,W);
    if 0
        
        for w=0:W-1
            c_rect(ind(2,:)/br+1+(ind(1,:)/ar)*Mr+w*M*N) = ... 
                coef(floor(ind_final(2,:)/b)+1+(ind_final(1,:)/a)*M+w*M*N);       
            c_rect(:,:,w+1) = phs.*c_rect(:,:,w+1);
        end;
        
    else
    
        tmp1=mod(s1*a*(L+1),2*N);
        
        for k=0:Nr-1   
            phsidx= mod(mod(tmp1*k,2*N)*k,2*N);
            
            for m=0:Mr-1
                phs = exp(-pi*1i*phsidx/N);
                
                idx1 =       mod(    k        ,N);
                idx2 = floor(mod(-s1*k*a+m*b,L)/b);
                
                for w=0:W-1    
                     c_rect(m+1,k+1,w+1) = coef(idx2+1,idx1+1,w+1).*phs;
                end;
            end;
        end;
        
    end;
    
    
    f = comp_idgt(c_rect,g,ar,[0 1],0,0);
        
else

    c_rect = zeros(Nr,Mr,W);
    p = comp_pchirp(L,-s0);

    g = p.*fft(g);

    twoN=2*N;
    cc1=ar/a;
    cc2=mod(-s0*br/a,twoN);
    cc3=mod(a*s1*(L+1),twoN);
    cc4=mod(cc2*br*(L+1),twoN);
    cc5=mod(2*cc1*br,twoN);
    cc6=mod((s0*s1+1)*br,L);
    
    for k=0:Nr-1   
        for m=0:Mr-1
            sq1=mod(k*cc1+cc2*m,twoN);
            phsidx = mod(mod(cc3*sq1.^2,twoN)-mod(m*(cc4*m+k*cc5),twoN),twoN);            
            phs = exp(-pi*1i*phsidx/N);
            
            idx1 =       mod(    k*cc1       +cc2*m,N);
            idx2 = floor(mod(-s1*k*ar+(s0*s1+1)*m*br,L)/b);
            
            for w=0:W-1                    
                c_rect(mod(-k,Nr)+1,m+1,w+1) = coef(idx2+1,idx1+1,w+1).*phs;
            end;
        end;
    end;                    
    
    f = comp_idgt(c_rect,g,br,[0 1],0,0);
    f = ifft(bsxfun(@times,comp_pchirp(L,s0),f));   
    
end

if s1 ~= 0
    f = bsxfun(@times,comp_pchirp(L,-s1),f);
end            
