classdef helperNNDPDInputPreprocessor < matlab.System
  %helperNNDPDInputPreprocessor Neural network DPD input preprocessor
  %   PREP = helperNNDPDInputPreprocessor(M,K) returns a neural network DPD
  %   preprocessor System object based on the augmented real-valued
  %   time-delay neural network (ARVTDNN).
  %
  %   The input features are I-Q samples (time-delayed samples and current
  %   sample I[n], Q[n]), and the amplitudes of the sample |X[n]|,
  %   |X[n]|^2, ..., |X[n]|^(K-1), as described in [1].
  %
  %   The input layer of the neural network is a concatenation of the
  %   following:
  %
  %   I[n-M+1], I[n-M+2], ..., I[n]
  %   Q[n-M+1], Q[n-M+3], ..., Q[n]
  %   |X[n-M+1]|, |X[n-M+1]|^2, ..., |X[n-M+1]|^(K-1)
  %   |X[n-M+2]|, |X[n-M+2]|^2, ..., |X[n-M+2]|^(K-1)
  %   ...
  %   |X[n]|, |X[n]|^2, ..., |X[n]|^(K-1)
  %
  %   During training, X is the output sample of the PA. During inference,
  %   X is the input of the DPD.
  %
  %   [1] Dongming Wang; Mohsin Aziz; Mohamed Helaoui; Fadhel M. Ghannouchi,
  %   "Augmented Real-Valued Time-Delay Neural Network for Compensation of
  %   Distortions and Impairments in Wireless Transmitters," IEEE
  %   Transactions on Neural Networks and Learning Systems
  %   https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=8383719
  %
  %   See also comm.DPD.

  %   Copyright 2023 The MathWorks, Inc.

  properties (Nontunable)
    MemoryDepth = 1
    NonlinearityOrder = 1
    OutputDataType (1,1) string ...
      {mustBeMember(OutputDataType,["double","single"])} = "single"
  end

  properties (Access=private)
    Buffer
    NumFeatures
    NonlinearityPowers
  end

  methods
    function obj = helperNNDPDInputPreprocessor(varargin)
      setProperties(obj,nargin,varargin{:}, ...
        "MemoryDepth","NonlinearityOrder");
    end
  end

  methods (Access=protected)
    function setupImpl(obj,~)
      % Setup internal properties
      obj.NonlinearityPowers = 1:obj.NonlinearityOrder-1;
      obj.NumFeatures = 2*obj.MemoryDepth ...
        +(obj.NonlinearityOrder-1)*obj.MemoryDepth;
    end
    function y = stepImpl(obj,x)
      % Process input, X, and output, Y. 
      numSamples = size(x,1);
      y = zeros(numSamples,obj.NumFeatures,obj.OutputDataType);
      for p = 1:numSamples
        % Feed from bottom or end of the input buffer
        obj.Buffer = [obj.Buffer(2:end), x(p,1)];
        y(p,:) = [real(obj.Buffer), imag(obj.Buffer), ...
          reshape(abs(obj.Buffer)'.^obj.NonlinearityPowers,1,[])];
      end
    end
    function resetImpl(obj)
      obj.Buffer = zeros(1,obj.MemoryDepth,obj.OutputDataType);
    end
  end
end