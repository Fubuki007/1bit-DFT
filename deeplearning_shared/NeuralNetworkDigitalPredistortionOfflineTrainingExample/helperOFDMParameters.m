function ofdmParams = helperOFDMParameters(bw,varargin)
% Based on requested BW, select 5G-like parameters

%   Copyright 2022-2023 The MathWorks, Inc.

switch bw
  case 5e6
    ofdmParams.scs = 30e3;
    ofdmParams.fftLength = 256;
    ofdmParams.NumDataSubcarriers = 132;
    ofdmParams.cpLength = 18;
    ofdmParams.windowLength = 6;
  case 15e6
    ofdmParams.scs = 30e3;
    ofdmParams.fftLength = 1024;
    ofdmParams.NumDataSubcarriers = 456;
    ofdmParams.cpLength = 72;
    ofdmParams.windowLength = 6;
  case 40e6
    ofdmParams.scs = 30e3;
    ofdmParams.fftLength = 2048;
    ofdmParams.NumDataSubcarriers = 1272;
    ofdmParams.cpLength = 144;
    ofdmParams.windowLength = 8;
  case 100e6
    ofdmParams.scs = 30e3;
    ofdmParams.fftLength = 4096;
    ofdmParams.NumDataSubcarriers = 3276;
    ofdmParams.cpLength = 288;
    ofdmParams.windowLength = 20;
end

ofdmParams.NumGuardBandCarrier = ofdmParams.fftLength - ofdmParams.NumDataSubcarriers;
if nargin > 1
  ofdmParams.OversamplingFactor = varargin{1};
else
  ofdmParams.OversamplingFactor = 1;
end
ofdmParams.SampleRate = ofdmParams.scs * ofdmParams.fftLength * ofdmParams.OversamplingFactor;
ofdmParams.Bandwidth = bw;
end