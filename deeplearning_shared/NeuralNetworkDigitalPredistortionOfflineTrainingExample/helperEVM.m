function [rmsEVM,rxQAMSym] = helperEVM(paOutput,qamRefSym,ofdmParams)
%helperEVM Error vector magnitude (EVM)
%   [E,Y] = helperEVM(X,REF,PARAMS) calculates EVM for signal, X, given the
%   reference signal, REF. X is OFDM modulated based on PARAMS.

%   Copyright 2023-2024 The MathWorks, Inc.

% Downsample and demodulate
waveform = ofdmdemod(paOutput,ofdmParams.fftLength,ofdmParams.cpLength,...
    ofdmParams.cpLength,[1:ofdmParams.NumGuardBandCarrier/2+1 ...
     ofdmParams.fftLength-ofdmParams.NumGuardBandCarrier/2+1:ofdmParams.fftLength]',...
     OversamplingFactor=ofdmParams.OversamplingFactor);
rxQAMSym = waveform(:)*ofdmParams.OversamplingFactor;

qamRefSym = qamRefSym(:);
if isempty(qamRefSym)
  M = 16;
  qamRefSym = qammod(qamdemod(rxQAMSym,M),M);
end

% Compute EVM
evm = comm.EVM;
rmsEVM = evm(qamRefSym,rxQAMSym);
end