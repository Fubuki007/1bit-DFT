%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% AllDigitalBeamforming.m 
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
% This function returns the spectral efficiency of the all-digital beamforming
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
% Fgnb: gNB all-digital precoder
% Fiab: IAB all-digital precoder
% Wiab: IAB all-digital combiner
% Wue: UE all-digital combiner
% normalize(X): function to normalize the columns of the matrix X
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Rb,Ra] = AllDigitalBeamforming(Hb,Ha,Hs,Ns,Ps,SNR,maxIter,Rb,Ra)
[Nue,Nbs] = size(Ha);

%% Initialize the all-digital beamformers
Fgnb = randn(Nbs,Ns) + 1i* randn(Nbs,Ns); Fgnb = normalize_column(Fgnb);
Fiab = randn(Nbs,Ns) + 1i* randn(Nbs,Ns); Fiab = normalize_column(Fiab);
Wiab = randn(Nbs,Ns) + 1i* randn(Nbs,Ns); Wiab = normalize_column(Wiab);
Wue = randn(Nue,Ns) + 1i* randn(Nue,Ns); Wue = normalize_column(Wue);


for ii=1:maxIter
% IAB combiner    
Hse = Hs*Fiab;
Riab = Ps*Hse*Hse' + 1/SNR*eye(Nbs);
Ri = inv(Riab);
Hbe = Hb*Fgnb;
Wiab = Ri*Hbe*inv(Hbe'*Ri*Hbe);
Wiab = normalize_column(Wiab);
 
% IAB precoder
Hse = Wiab'*Hs;
Siab = Ps*Hse'*Hse + 1/SNR*eye(Nbs);
Si = inv(Siab);
Hae = Wue'*Ha;
Fiab = Si*Hae'*inv( Hae*Si*Hae' );
Fiab = normalize_column(Fiab);

% UE combiner
Hae = Ha*Fiab;
Wue = inv(Hae*Hae' + Nue/SNR*eye(Nue))*Hae; 
Wue = normalize_column(Wue);

% gNB precoder
Hbe = Wiab'*Hb;
Fgnb = inv(  Hbe'*Hbe + Nbs/SNR*eye(Nbs) ) * Hbe';
Fgnb = normalize_column(Fgnb);

end

% Effective channels
Hbe = Wiab'*Hb*Fgnb;
Hae = Wue'*Ha*Fiab;
Hse = Wiab'*Hs*Fiab;

% Covariance matrix of self-interference and noise power
Qb = Ps*Hse*Hse' + 1/SNR*Wiab'*Wiab;

% Covariance matrix of noise power
Qa = 1/SNR*Wue'*Wue;

% Spectral efficiency for backhaul link
Rb_tmp = real(log2(det( eye(Ns) + Hbe*inv(Qb)*Hbe'  )));

% Spectral efficiency for access link
Ra_tmp = real(log2(det( eye(Ns) + Hae*inv(Qa)*Hae'  )));

Rb = Rb_tmp + Rb;
Ra = Ra_tmp + Ra;

end