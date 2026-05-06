function [paOutput,results] = helperNNDPDPAMeasure(txWaveform, sr, VST)
%helperNNDPDPAMeasure Measure PA input and output signals
%   Y = helperNNDPDPAMeasure(X,P,R) sends the input signal, X, through the
%   PA using the VST. The sample rate is R. The measured PA output signal
%   is returned as Y.
%
%   See also NeuralNetworkDigitalPredistortionOfflineTrainingExample.

%   Copyright 2021-2023 The MathWorks, Inc.

acquisitionTime = (length(txWaveform) / sr) + 30e-6;

% Configure VST
VST.AcquisitionTime = acquisitionTime;  % s

% Send the signals to the PA and collect the outputs
testSignal = "OFDM";
writeWaveform(VST,txWaveform,sr,testSignal)

configure(VST);
startTx(VST);
results = runRx(VST);
stopTx(VST);
paOutput = double(results.OutputWaveform);

% Time synchronization
delay = finddelay(txWaveform,paOutput);
paOutput = paOutput(1+delay:delay+length(txWaveform));

% Normalize power of output signal
paOutput = paOutput/norm(paOutput)*norm(txWaveform);
end
