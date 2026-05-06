function sa = helperPACharPlotSpectrum(x,desc,sampleRate,testSignal,varargin)
%helperPACharPlotSpectrum Plot PA characterization results
%   S = helperPACharPlotSpectrum(POUT,POUTFIT,TYPE,R,TEST) plots the
%   spectrum of the measured PA output, POUT, and the estimated PA output,
%   POUTFIT when TYPE is 'spectrum'. R is the sample rate and TEST is the
%   test signal type, which can be "Tones" or "Modulated".
%
%   See also PowerAmplifierCharacterizationExample.

%   Copyright 2020-2023 The MathWorks, Inc.

sa = spectrumAnalyzer;
sa.SpectrumType = 'Power';
sa.SampleRate = sampleRate;
sa.SpectralAverages = 16;
sa.ReferenceLoad = 100;
if strcmp(testSignal, "Tones")
  sa.DistortionMeasurements.Enable = true;
  sa.DistortionMeasurements.Algorithm = "Intermodulation";
  if nargin > 4
    sa.YLimits = varargin{1};
  else
    sa.YLimits = [-80 60];
  end
else
  if nargin > 4
    sa.YLimits = varargin{1};
  else
    sa.YLimits = [-80 30];
  end
end
sa.ChannelNames = desc;
sa(x)
sa.ShowLegend = true;
