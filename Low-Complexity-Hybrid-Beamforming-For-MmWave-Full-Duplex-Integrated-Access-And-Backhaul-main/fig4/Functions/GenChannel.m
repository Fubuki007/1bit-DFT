%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GenChannel.m 
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
% This script returns the mmWave geometric channel
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function H=GenChannel(Ncl,Nray,std_phi,std_theta,Pr,Nt,Nr,epsilon,zeta)
% mmWave MIMO Channel Model

% Ncl   : number of clusters
% Nray  : number of rays per cluster
% Nt    : number of tx antenna
% Nr    : number of rx antenna
% alpha :  iid CN(0,sigma_i) sigma_i average power of i cluster.
% Ar    : rx steering vector
% At    : tx steering vector


%% 

L=Ncl*Nray;

phi_cl   = 0 + 2*pi*rand(Ncl,1);
phi_cl   = sin(phi_cl);
theta_cl = 0 + 2*pi*rand(Ncl,1);
theta_cl = sin(theta_cl);


phi   = repmat(phi_cl,  [1 Nray]) + std_phi  *randn(Ncl,Nray);
theta = repmat(theta_cl,[1 Nray]) + std_theta*randn(Ncl,Nray);


%% 

% epsilon:  antenna position of BS in lambda/2 
% zeta:     antenna position of UE in lambda/2

At=zeros(Nt,L);
for i=1:L
   At(:,i)=[exp(1i*pi*phi(i)*epsilon(:))]/sqrt(Nt);   
end

Ar=zeros(Nr,L);
for i=1:L
   Ar(:,i)=[exp(1i*pi*theta(i)*zeta(:))]/sqrt(Nr);   
end


%% Path losses
var_cluster=Pr*ones(Ncl,1); % all clusters equal power
alpha = repmat((sqrt(var_cluster)/2),[1 Nray]).*(randn(Ncl,Nray)+i*randn(Ncl,Nray));

alpha=alpha(:);
[a I]= sort(abs(alpha),'descend');
alpha=alpha(I);

%%
H=Ar(:,I)*diag(alpha)*At(:,I)';

rho=Nt*Nr/(norm(H,'fro')^2);
H=H*sqrt(rho);


end



