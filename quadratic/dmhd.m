function r = dmhd(f);
%DMHD discrete Margenau-Hill distribution
%   Usage W = dmhd(f);
%
%   Input parameters:
%         f      : Input signal
%
%   Output parameters:
%         d      : discrete Margenau-Hill distribution
%
% `dmhd(f)` computes a discrete Margenau-Hill distribution.
% The discrete Margenau-Hill distribution is the real part of
%
% .. math:: r\left( l,\; k \right)\; =\; \sum_{l\; =\; 0}^{L\; -\; 1}{f\left( l \right)\overline{f\left( l\; -\; h \right)}e^{-2\pi ikh/L}}
%

% AUTHOR: Jordy van Velthoven

r = real(drd(f));