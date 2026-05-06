%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SelfInterferenceChannel.m 
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
% This script returns the self-interference channel 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function output = SelfInterferenceChannel(d,an,kappa,Ncl,Nray,std_phi,std_theta,Pr,Nt,Nr,epsilon,zeta)

    % Self-interference matrices

    % Channel parameters: Hlos. Narrowband far-field LOS channel model    
    dot = d/tan(an); dos = d/sin(an);
    for row=1:Nr
        for col=1:Nt
            R(row,col) = sqrt((dot+(col-1)/2)^2+(dos+(row-1)/2)^2 -...
                2*(dot+(col-1)/2)*(dos+(row-1)/2)*cos(an));
        end
    end
    Hlos = exp(-i*2*pi*R)./R;
    T = trace(Hlos*Hlos');
    Hlos = Hlos*sqrt(Nt*Nr/T);
    
   [Hnlos,~,~]=GenChannel(Ncl,Nray,std_phi,std_theta,Pr,Nt,Nr,epsilon,zeta);
    
    output = 1/(sqrt(kappa+1)) * ( sqrt(kappa)* Hlos + Hnlos  );
    
    output = sqrt(Nt*Nr/norm(output,'fro')^2)*output;
    
    
end