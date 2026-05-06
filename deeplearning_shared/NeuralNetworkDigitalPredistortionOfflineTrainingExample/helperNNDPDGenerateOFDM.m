function [txWaveform,qamRefSym] = helperNNDPDGenerateOFDM(ofdmParams,spf,M,outputDataType)
%helperNNDPDGenerateOFDM OFDM symbol generator
%   [X,S] = helperNNDPDGenerateOFDM(P,N,M) generates N OFDM symbols based
%   on the OFDM parameter structure, P and returns in X. Each OFDM data
%   subcarrier carries an M-ary QAM modulated symbol. S is the QAM symbols.
%   The output is upsampled by a factor of seven.
%
%   See also NeuralNetworkDigitalPredistortionOfflineTrainingExample.

%   Copyright 2021-2023 The MathWorks, Inc.

arguments
  ofdmParams
  spf
  M
  outputDataType (1,1) {mustBeMember(outputDataType,["double","single"])} = "single"
end

numDataCarriers = (ofdmParams.fftLength - ofdmParams.NumGuardBandCarrier - 1);
nullIdx = [1:ofdmParams.NumGuardBandCarrier/2+1 ...
  ofdmParams.fftLength-ofdmParams.NumGuardBandCarrier/2+1:ofdmParams.fftLength]';

% Random data
x = randi([0 M-1],numDataCarriers,spf,outputDataType);

% OFDM with 16-QAM in data subcarriers
qamRefSym = qammod(x,M);
osf = ofdmParams.OversamplingFactor;
txWaveform = ofdmmod(qamRefSym/osf,ofdmParams.fftLength, ...
                            ofdmParams.cpLength, ...
                            nullIdx, ...
                            OversamplingFactor=osf);
end
