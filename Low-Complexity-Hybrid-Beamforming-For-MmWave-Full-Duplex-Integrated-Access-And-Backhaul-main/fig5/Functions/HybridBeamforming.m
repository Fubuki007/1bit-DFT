%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% HybridBeamforming.m 
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
% This function returns the spectral efficiency of the hybrid analog/digital beamforming 
%% Parameters 
% Ra, Rb: spectral efficiency for access, backhaul links
% maxIter: number of iterations to obtain the convergence of Algorithm I
% Hb: backhaul channel
% Ha: access channel
% Hs: self-interference channel
% Nbs: number of BS antennas
% Nue: number of UE antennas
% Nrf:number of RF chains
% Ns: number of spatial streams
% Ps: self-interference power
% SNR: signal-to-noise-ratio 
% Fgnbrf: gNB analog precoder
% Fiabrf: IAB analog precoder
% Wiabrf: IAB analog combiner
% Wuerf: UE analog combiner
% Fgnbbb: gNB digital precoder
% Fiabbb: IAB digital precoder
% Wiabbb: IAB digital combiner
% Wuebb: UE digital combiner
% Fgnb: gNB hybrid precoder
% Fiab: IAB hybrid precoder
% Wiab: IAB hybrid combiner
% Wue: UE hybrid combiner
% normalize_column(X): function to normalize the column of the matrix X
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Rb,Ra] = HybridBeamforming(Hb,Ha,Hs,Ns,Nrf,Ps,SNR,maxIter,Rb,Ra)


[Nue,Nbs] = size(Ha);

%% Initialize the analog beamformers
Fgnbrf = randn(Nbs,Nrf) + 1i* randn(Nbs,Nrf); Fgnbrf = normalize_column(Fgnbrf);
Fiabrf = randn(Nbs,Nrf) + 1i* randn(Nbs,Nrf); Fiabrf = normalize_column(Fiabrf);
Wiabrf = randn(Nbs,Nrf) + 1i* randn(Nbs,Nrf); Wiabrf = normalize_column(Wiabrf);
Wuerf = randn(Nue,Nrf) + 1i* randn(Nue,Nrf); Wuerf = normalize_column(Wuerf);

%% Initialize the digital beamformers
Fgnbbb = randn(Nrf,Ns) + 1i* randn(Nrf,Ns); Fgnbbb = normalize_column(Fgnbbb);
Fiabbb = randn(Nrf,Ns) + 1i* randn(Nrf,Ns); Fiabbb = normalize_column(Fiabbb);
Wiabbb = randn(Nrf,Ns) + 1i* randn(Nrf,Ns); Wiabbb = normalize_column(Wiabbb);
Wuebb = randn(Nrf,Ns) + 1i* randn(Nrf,Ns); Wuebb = normalize_column(Wuebb);

for ii=1:maxIter

%% Analog Beamforming

% Analog IAB Combiner
Hse = Hs*Fiabrf;
Riab = Ps*Hse*Hse' + 1/SNR*eye(Nbs);
Ri = inv(Riab);
Hbe = Hb*Fgnbrf;
Wiabrf = Ri*Hbe*inv(Hbe'*Ri*Hbe);
Wiabrf = 1/sqrt(Nbs)*exp(1i*angle(Wiabrf)); % CA Constraint

% Analog IAB Precoder
Hse = Wiabrf'*Hs;
Siab = Ps*Hse'*Hse + 1/SNR*eye(Nbs);
Si = inv(Siab);
Hae = Wuerf'*Ha;
Fiabrf = Si*Hae'*inv( Hae*Si*Hae' );
Fiabrf = 1/sqrt(Nbs)*exp(1i*angle(Fiabrf)); % CA Constraint

% Analog UE Combiner
Hae = Ha*Fiabrf;
Wuerf = inv(Hae*Hae' + Nue/SNR*eye(Nue))*Hae; 
Wuerf = 1/sqrt(Nue)*exp(1i*angle(Wuerf)); % CA Constraint

% Analog gNB Precoder
Hbe = Wiabrf'*Hb;
Fgnbrf = inv(  Hbe'*Hbe + Nbs/SNR*eye(Nbs) ) * Hbe'; 
Fgnbrf = 1/sqrt(Nbs)*exp(1i*angle(Fgnbrf)); % CA Constraint



%% Digital Beamforming
Fgnb = Fgnbrf*Fgnbbb; 
Fiab = Fiabrf*Fiabbb; 
Wiab = Wiabrf*Wiabbb;
Wue = Wuerf*Wuebb;   

% Digital gNB Precoder
Fgnbbb = DigitalBeamforming(Fgnbrf,Hb'*Wiab,Ns); 
Fgnbbb = normalize_column(Fgnbbb); % Normalize the transmit power at the gNB

% Digital IAB Precoder
Fiabbb = DigitalBeamforming(Fiabrf,Ha'*Wue,Ns);  
Fiabbb = normalize_column(Fiabbb);% Normalize the transmit power at the IAB

% Digital IAB Combiner
Wiabbb = DigitalBeamforming(Wiabrf,Hb*Fgnb,Ns); 

% Digital UE Combiner
Wuebb = DigitalBeamforming(Wuerf,Ha*Fiab,Ns);    


end

% Hybrid beamfomers
Fgnb = Fgnbrf*Fgnbbb; 
Fiab = Fiabrf*Fiabbb; 
Wiab = Wiabrf*Wiabbb; 
Wue = Wuerf*Wuebb;    

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