%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% UpperBound.m 
%
% Created Feb, 2023
% Elyes Balti
% The University of Texas at Austin
%
% If you use this code or any (modified) part of it in any publication, please cite 
% the following paper: 
% 
% E. Balti, C. Dick and B. L. Evans,
% "Low Complexity Hybrid Beamforming for mmWave Full-Duplex Integrated Access and Backhaul," 
% GLOBECOM 2022 - 2022 IEEE Global Communications Conference, Rio de Janeiro, Brazil, 2022, pp. 1606-1611
%
%
% Contact email: ebalti@utexas.edu
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Description
% This function returns the spectral efficiency of the upper bound 
%% Parameters 
% Ra, Rb: spectral efficiency for access, backhaul links
% Hb: backhaul channel
% Ha: access channel
% Ns: number of spatial streams
% SNR: signal-to-noise-ratio 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Rb,Ra] = UpperBound(Hb,Ha,Ns,SNR,Rb,Ra)

[~,Sb,~] = svd(Hb);
[~,Sa,~] = svd(Ha);

Sa = Sa(1:Ns,1:Ns);
Sb = Sb(1:Ns,1:Ns);

Rb_tmp = log2(det(eye(Ns) + SNR* Sb*Sb'  ));
Ra_tmp = log2(det(eye(Ns) + SNR* Sa*Sa'  ));

Rb = Rb_tmp + Rb;
Ra = Ra_tmp + Ra;

end