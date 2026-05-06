%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RelatedWork.m 
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
% This function returns the spectral efficiency of related work
% I. P. Roberts, H. B. Jain and S. Vishwanath, "Frequency-Selective Beamforming Cancellation Design for Millimeter-Wave Full-Duplex," 
% ICC 2020 - 2020 IEEE International Conference on Communications (ICC), Dublin, Ireland, 2020
% referenced [8] in our conference paper
% Note: We reproduce the results/algorithm of work [8] for narrowband
% fading in our case. It is noteworthy to state that work [8] considered frequency selective channel.
%% Parameters 
% Ra, Rb: spectral efficiency for access, backhaul links
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
% Arb: array response at IAB
% Atb: array steering at gNB
% Ara: array response at UE
% Ata: array steering at IAB
% normalize_column(X): function to normalize the column of the matrix X
% omp_precoding: function to decompose a given all-digital beamformer into the
% equivalent analog and digital beamformers using the Orthogonal Matching
% Pursuit (OMP) technique
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Rb,Ra] = RelatedWork(Hb,Ha,Hs,Nrf,Ns,Ps,SNR,Arb,Atb,Ara,Ata,Rb,Ra)

[Ua,~,Va] = svd(Ha);
[Ub,~,Vb] = svd(Hb);

Fgnb = Vb(:,1:Ns);
Wiab = Ub(:,1:Ns);
Fiab = Va(:,1:Ns);
Wue = Ua(:,1:Ns);

% Decomposing the all-digital beamformers into the equivalent analog and
% digital beamformers
[Fgnbrf,Fgnbbb] = omp_precoding(Fgnb,Nrf,Ns,Atb);
[Fiabrf,Fiabbb] = omp_precoding(Fiab,Nrf,Ns,Ata);
[Wiabrf,Wiabbb] = omp_precoding(Wiab,Nrf,Ns,Arb);
[Wuerf,Wuebb] = omp_precoding(Wue,Nrf,Ns,Ara);


Hint = Wiabbb'*Wiabrf'*Hs*Fiabrf;
Hdes = Wuebb'*Wuerf'*Ha*Fiabrf;

% LMMSE eq. 23 in [8]
Fiabbb = inv( Hdes*Hdes' + Ps/SNR*Hint*Hint' + Nrf/SNR *eye(Nrf)  ) * Hdes';
Fiabbb = normalize_column(Fiabbb);

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

% Spectral efficiency of backhaul link
Rb_tmp = real(log2(det( eye(Ns) + Hbe*inv(Qb)*Hbe'  )));

% Spectral efficiency of access link
Ra_tmp = real(log2(det( eye(Ns) + Hae*inv(Qa)*Hae'  )));

Rb = Rb_tmp + Rb;
Ra = Ra_tmp + Ra;


end