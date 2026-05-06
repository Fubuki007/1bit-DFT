classdef helperVSTDriver < handle
  %helperVSTDriver NI PXIe VST Driver
  %   VST = helperVSTDriver(RESOURCE) returns an NI PXIe VST driver object,
  %   VST, for the resource name, RESOURCE. 
  %
  %   See also PowerAmplifierCharacterizationExample.
  
  %   Copyright 2020-2023 The MathWorks, Inc.
  
  properties (SetAccess = private)
    ResourceName
  end
  
  properties (Dependent)
    CenterFrequency
    SampleRate
    ExternalAttenuation
    DUTTargetInputPower
    DUTExpectedGain
    DUTExpectedGainAccuracy
    AcquisitionTime
  end
  
  properties (Access = private)
    VST
    SignalType
  end
  
  methods
    function set.CenterFrequency(obj, val)
      obj.VST.CenterFrequency = val;
    end
    function val = get.CenterFrequency(obj)
      val = obj.VST.CenterFrequency;
    end
    
    function set.SampleRate(obj, val)
      obj.VST.VSG.SampleRate = val;
    end
    function val = get.SampleRate(obj)
      val = obj.VST.VSG.SampleRate;
    end
    
    function set.ExternalAttenuation(obj, val)
      obj.VST.VSA.ExternalAttenuation = val;
    end
    function val = get.ExternalAttenuation(obj)
      val = obj.VST.VSA.ExternalAttenuation;
    end
    
    function set.DUTTargetInputPower(obj, val)
      obj.VST.DUTTargetInputPower = val;
    end
    function val = get.DUTTargetInputPower(obj)
      val = obj.VST.DUTTargetInputPower;
    end
    
    function set.DUTExpectedGain(obj, val)
      obj.VST.DUTExpectedGain = val;
    end
    function val = get.DUTExpectedGain(obj)
      val = obj.VST.DUTExpectedGain;
    end
    
    function set.DUTExpectedGainAccuracy(obj, val)
      obj.VST.DUTExpectedGainAccuracy = val;
    end
    function val = get.DUTExpectedGainAccuracy(obj)
      val = obj.VST.DUTExpectedGainAccuracy;
    end
    
    function set.AcquisitionTime(obj, val)
      obj.VST.VSA.AcquisitionTime = val;
    end
    function val = get.AcquisitionTime(obj)
      val = obj.VST.VSA.AcquisitionTime;
    end
  end
  
  methods
    function obj = helperVSTDriver(resourceName, varargin)
      obj.VST = NIVSTDriver(resourceName, varargin{:});
      obj.ResourceName = resourceName;
      
      % Configure the VSG and VSA to use the same clock source as frequency
      % reference to ensure clock synchronization.  
      obj.VST.VSG.FrequencyReference = 'Onboard Clock';
      obj.VST.VSA.FrequencyReference = 'Onboard Clock';
      
      % The VSG generates a trigger signal and the VSA uses this trigger
      % signal to start measurements. Configure the trigger signal. VSG
      % sends the trigger signal using the 'PXI Trigger Line 0', while the
      % VSA uses the same line to receive. Set trigger edge to the rising
      % edge.
      obj.VST.VSG.MarkerEventDestination = 'PXI Trigger Line 0';
      obj.VST.VSA.TriggerSource = 'PXI Trigger Line 0';
      obj.VST.VSA.TriggerEdge = 'Rising';
      obj.VST.VSA.TriggerDelay = 0; % seconds
      
      % Since the VSG output does not have any attenuator, set the VSG
      % external attenuation to 0 dB.
      obj.VST.VSG.ExternalAttenuation = 0;
      
      % Set the acquisition and measurement timeouts to 10 seconds. 
      obj.VST.VSA.AcquisitionTimeout = 10; % seconds
      obj.VST.VSA.MeasurementTimeout = 10; % seconds
      
      % Set the expected gain accuracy to 1 dB
      obj.DUTExpectedGainAccuracy = 1;
    end
    
    function writeWaveform(obj,waveform,fs,testSignal)
      % Zero padding in the front and in the end
      % For the front part, the zero padding must be longer than the
      % number of delayed samples caused by VSG. The zero padding at the end is
      % needed to assure unclipped signal.
      paddingLength = round(30e-6*fs);
      paddedSig = [zeros(paddingLength,1); waveform; zeros(1e5,1)];
      
      obj.VST.SampleRate = fs;
      
      refWaveformName = 'ref';
      addWaveform(obj.VST, refWaveformName, paddedSig);
      setWaveformSampleRate(obj.VST, refWaveformName, fs);
      setWaveformSignalBandwidth(obj.VST, refWaveformName, 0.8 * fs);
      waveformPAPR = 20*log10(max(abs(waveform)) / rms(waveform));
      setWaveformPAPR(obj.VST, refWaveformName, waveformPAPR);
      setWaveformRuntimeScaling(obj.VST, refWaveformName, -1.5);
      
      if strcmp(testSignal, "OFDM")
        signalType = 'Modulated';
      elseif strcmp(testSignal, "Tones")
        signalType = 'Tones';
      end
      obj.SignalType = signalType;
    end
    
    function results = runPAMeasurements(obj)
      configure(obj.VST)
      configureMeasurement(obj.VST, 'SpecAn AM/AM', 'SignalType', obj.SignalType)
      activateWaveform(obj.VST,'ref')
      enableAllTraces = true;
      selectMeasurements(obj.VST, {'SpecAn AM/AM'}, enableAllTraces)
      results = run(obj.VST);
      results = results.AMAM;
    end
    
    function results = configure(obj)
      configure(obj.VST)
      configureMeasurement(obj.VST, 'SpecAn AM/AM', 'SignalType', obj.SignalType)
      activateWaveform(obj.VST,'ref')
      enableAllTraces = true;
      selectMeasurements(obj.VST, {'SpecAn AM/AM'}, enableAllTraces)
    end
    
    function success = startTx(obj)
      success = startTx(obj.VST);
    end
    
    function success = stopTx(obj)
      success = stopTx(obj.VST);
    end
    
    function results = runRx(obj)
      results = runRx(obj.VST);
      results = results.AMAM;
    end
    
    function release(obj)
      release(obj.VST)
    end
  end
end

