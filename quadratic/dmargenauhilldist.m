function d = dmargenauhilldist(f);
%DMARGENAUHILLDIST discrete Margenau-Hill distribution
%   Usage d = dmargenauhilldist(f);
%
%   Input parameters:
%         f      : Input vector
%
%   Output parameters:
%         d      : discrete Margenau-Hill distribution
%
%   `dmargenauhilldist(f)` computes a discrete Margenau-Hill distribution.
%   The discrete Margenau-Hill distribution is the real part of 
%   the discrete Rihaczak distribution |drihaczekdist|.
%
%   see also: drihaczekdist
%
% AUTHOR: Jordy van Velthoven

d = real(drd(f));