%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% params.m 
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
% an: omega (angle between TX and RX at the full-duplex BS)
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

Path = pwd;
addpath([Path '/Functions']);
Ncl = 6;      
Nray = 8;     
std_phi   =   20;   std_phi = deg2rad(std_phi);
std_theta = 20; std_theta = deg2rad(std_theta);
Pr = 1;       
Nbs = 32;
Nue = 4;
Nrf = 2;
Ns = 2;
BSpos = [0:Nbs-1];  
UEpos = [0:Nue-1];     
d = 2;       
an = pi/6; 
kappa = 5; kappa = db2pow(kappa);
Ps = 15; Ps = db2pow(Ps);
noise_var_dB = 0;
noise_var = db2pow(noise_var_dB);
SNR = 1./noise_var;
MonteCarlo = 1e3;
maxIter = 21;


