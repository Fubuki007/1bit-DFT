%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SVDBeamforming.m 
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
% This function returns the hybrid analog/digital beamformers 
%% Parameters 
% Ra, Rb: spectral efficiency for access, backhaul links
% maxIter: number of iterations to obtain the convergence of Algorithm I
% Hb: backhaul channel
% Ha: access channel
% Hs: self-interference channel
% Nbs: number of BS antennas
% Nue: number of UE antennas
% Ns: number of spatial streams
% Ps: self-interference power
% SNR: signal-to-noise-ratio 
% Fgnb: gNB precoder
% Fiab: IAB precoder
% Wiab: IAB  combiner
% Wue: UE combiner
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Rb, Ra] = SVDBeamforming(Hb,Ha,Hs,Ns,Ps,SNR,Rb,Ra)

[U,~,V] = svd(Ha);
Fiab = V(:,1:Ns);
Wue = U(:,1:Ns);

[U,~,V] = svd(Hb);
Fgnb = V(:,1:Ns);
Wiab = U(:,1:Ns);


% Effective channels
Hbe = Wiab'*Hb*Fgnb;
Hae = Wue'*Ha*Fiab;
Hse = Wiab'*Hs*Fiab;

% Covariance matrix of self-interference and noise power
Qb = Ps*Hse*Hse' + 1/SNR*Wiab'*Wiab;

% Covariance matrix of noise power
Qa = 1/SNR* Wue'*Wue;

% Spectral efficiency for backhaul link
Rb_tmp = real(log2(det( eye(Ns) + Hbe*inv(Qb)*Hbe'  )));

% Spectral efficiency for access link
Ra_tmp = real(log2(det( eye(Ns) + Hae*inv(Qa)*Hae'  )));


Rb = Rb_tmp + Rb;
Ra = Ra_tmp + Ra;



end