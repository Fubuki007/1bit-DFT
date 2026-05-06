%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% main.m 
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
% This script defines the variables with their assigned values 
%% Parameters 
% Ca, Cb: spectral efficiency of all-digital beamforming for access, backhaul links
% Ra, Rb: spectral efficiency of proposed hybrid beamforming for access, backhaul links
% SVDa, SVDb: spectral efficiency of all-digital SVD beamforming for access, backhaul links
% Ua, Ub: spectral efficiency of upper bound for access, backhaul links
% Rhda, Rhdb: spectral efficiency of proposed hybrid beamforming half-duplex for access, backhaul links
% Ia, Ib: spectral efficiency of work [8] for access, backhaul links
% MonteCarlo: number of generation of random samples
% maxIter: number of iterations to obtain the convergence of Algorithm I
% Hb: backhaul channel
% Ha: access channel
% Hs: self-interference channel
% Ncl: number of clusters
% Nray: number of rays per cluster
% std_phi: AoD angular spread
% std_theta: AoA angular spread
% Pr: average received power per cluster
% Nbs: number of BS antennas
% Nue: number of UE antennas
% BSpos: ULA BS array position in lambda/2
% UEpos: ULA UE array position in lambda/2
% d: distance between the TX and RX arrays at the full-duplex BS
% an: angle separation between the TX and RX arrays at the full-duplex BS
% Nrf:number of RF chains
% Ns: number of spatial streams
% kappa: Rician factor
% Ps: self-interference power
% noise_var_dB (noise_var): noise variance defined in dB (Watt)
% SNR: signal-to-noise-ratio for which we normalize the average received
% power to 0 dB so that Ps is the amount of self-interference measured
% above the average received power. Hence, we vary the SNR by changing the
% noise variance
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


clear all;close all;clc
dbstop if error
params


%% Initialize the vectors of spectral efficiency
Cb = zeros(length(SNR),1);
Ca = zeros(length(SNR),1);
Rb = zeros(length(SNR),1);
Ra = zeros(length(SNR),1);
SVDb = zeros(length(SNR),1);
SVDa = zeros(length(SNR),1);
Rhdb = zeros(length(SNR),1);
Rhda = zeros(length(SNR),1);
Ub = zeros(length(SNR),1);
Ua = zeros(length(SNR),1);
Ib = zeros(length(SNR),1);
Ia = zeros(length(SNR),1);


for ii=1:length(SNR)
     ii
    for kk=1:MonteCarlo

%% Generate the channels
[Hb,Arb,Atb]=GenChannel(Ncl,Nray,std_phi,std_theta,Pr,Nbs,Nbs,BSpos,BSpos);
[Ha,Ara,Ata]=GenChannel(Ncl,Nray,std_phi,std_theta,Pr,Nbs,Nue,BSpos,UEpos);
Hs = SelfInterferenceChannel(d,an,kappa,Ncl,Nray,std_phi,std_theta,Pr,Nbs,Nbs,BSpos,BSpos);

%% All-Digital beamforming
[Cb(ii),Ca(ii)] = AllDigitalBeamforming(Hb,Ha,Hs,Ns,Ps,SNR(ii),maxIter,Cb(ii),Ca(ii));

%% Proposed full-duplex hybrid beamforming
[Rb(ii),Ra(ii)] = HybridBeamforming(Hb,Ha,Hs,Ns,Nrf,Ps,SNR(ii),maxIter,Rb(ii),Ra(ii));

%% half-duplex beamforming (set Ps = 0 Watt)
[Rhdb(ii),Rhda(ii)] = HybridBeamforming(Hb,Ha,Hs,Ns,Nrf,0,SNR(ii),maxIter,Rhdb(ii),Rhda(ii));

%% SVD beamforming
[SVDb(ii), SVDa(ii)] = SVDBeamforming(Hb,Ha,Hs,Ns,Ps,SNR(ii),SVDb(ii), SVDa(ii));
              
%% Related work [8]
 [Ib(ii),Ia(ii)] = RelatedWork(Hb,Ha,Hs,Nrf,Ns,Ps,SNR(ii),Arb,Atb,Ara,Ata,Ib(ii),Ia(ii));    

%% Upper bound
 [Ub(ii),Ua(ii)] = UpperBound(Hb,Ha,Ns,SNR(ii),Ub(ii),Ua(ii));

    end


end

%% Averaging over monte carlo iterations
Ca = Ca/MonteCarlo;
Cb = Cb/MonteCarlo;
Ra = Ra/MonteCarlo;
Rb = Rb/MonteCarlo;
SVDa = SVDa/MonteCarlo;
SVDb = SVDb/MonteCarlo;
Rhda = Rhda/MonteCarlo;
Rhdb = Rhdb/MonteCarlo;
Ua = Ua/MonteCarlo;
Ub = Ub/MonteCarlo;
Ia = Ia/MonteCarlo;
Ib = Ib/MonteCarlo;

%% Numerical results
figure; hold on
plot(SNR_dB,Ub+Ua,'-^','linewidth',2);
plot(SNR_dB,Cb+Ca,'-o','linewidth',2);
plot(SNR_dB,Rb+Ra,'--d','linewidth',2);
plot(SNR_dB,SVDb+SVDa,'g-o','linewidth',2);
plot(SNR_dB,Ib+Ia,'m--s','linewidth',2);
plot(SNR_dB,(Rhdb+Rhda)/2,'--x','linewidth',2);
legend('Upper Bound','All-Digital','Proposed','SVD','Work [8]','Half-Duplex','location','best')
xlabel('SNR (dB)')
ylabel('Sum Spectral Efficiency (bits/s/Hz)')

print('Fig5','-djpeg');







