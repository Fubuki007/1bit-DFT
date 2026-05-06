function y = helperNNDPDMemoryPolynomial(x,paInputTrain,paOutputTrain,deg,memLen)
%helperNNDPDMemoryPolynomial Memory polynomial DPD
%   Y = helperNNDPDMemoryPolynomial(X,XTrain,YTrain,K,M) trains a
%   cross-term memory polynomial DPD with polynomial degree, K, and memory
%   length, M, using PA input signal XTrain and PA output signal YTain.
%   Then applies digital predistortion to input X to generate output Y to
%   be used as PA input.
%
%   See also NeuralNetworkDigitalPredistortionOfflineTrainingExample.

%   Copyright 2021-2023 The MathWorks, Inc.

warnState = warning("off","MATLAB:rankDeficientMatrix");
stateReset = onCleanup(@()warning(warnState));

estimator = comm.DPDCoefficientEstimator( ...
  'DesiredAmplitudeGaindB',0, ...
  'PolynomialType','Cross-term memory polynomial', ...
  'Degree',deg,'MemoryDepth',memLen,'Algorithm','Least squares');
coef = estimator(paInputTrain,paOutputTrain);
dpdMem = comm.DPD('PolynomialType','Cross-term memory polynomial', ...
  'Coefficients',coef);

% Send data to DPD
y = dpdMem(x);
end