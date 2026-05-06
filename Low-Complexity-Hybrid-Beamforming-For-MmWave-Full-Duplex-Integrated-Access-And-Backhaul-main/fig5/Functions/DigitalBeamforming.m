%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DigitalBeamforming.m 
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
% This function returns the digital beamformer
%% Parameters 
% Xbb: digital beamformer 
% Xrf: analog beamformer
% A: beamformed channel
% N: number of spatial streams
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function Xbb = DigitalBeamforming(Xrf,A,N)
[Urf,Srf,Vrf] = svd(Xrf);
[r,c] = size(Srf); rr = min(r,c);S = Srf(1:rr,1:rr);
B = Urf'*A;
[R,~,~] = svd(B);
Q = R(:,1:N);
Si = inv(S);
Ss = Srf; Ss(1:rr,1:rr) = Si;
Xbb = Vrf*Ss.'*Q;
end