classdef SpecAnAMAMMeasurement < Measurement
  %SpecAnAMAMMeasurement NI RFmx SpecAn measurements
  %   SPECANMES = SpecAnAMAMMeasurement returns an NI RFmx SpecAn
  %   measurements object, SPECANMES.
  %
  %   See also PowerAmplifierCharacterizationExample, helperVSTDriver,
  %   NIRFmxDriver, NIRFmxSpecAn. 
  
  %   Copyright 2020 The MathWorks, Inc.

  properties (Constant)
    Name = 'AM/AM'
    Type = NationalInstruments.RFmx.SpecAnMX.RFmxSpecAnMXMeasurementTypes.Ampm
  end

  properties
    SignalType = 'Modulated'
  end
  
  methods
    function obj = SpecAnAMAMMeasurement(specAnDriver, varargin)
      % specAnDriver is the handle of the parent object (NIRFmxSpecAn)
      obj@Measurement(specAnDriver, varargin{:})
    end
    
    function configure(obj)
      import NationalInstruments.RFmx.SpecAnMX.*;
      
      ampmreferenceWaveformIdleDurationPresent = RFmxSpecAnMXAmpmReferenceWaveformIdleDurationPresent.False;
      if strcmp(obj.SignalType, 'Tones')
        ampmWaveformSignalType = RFmxSpecAnMXAmpmSignalType.Tones;
      else
        ampmWaveformSignalType = RFmxSpecAnMXAmpmSignalType.Modulated;
      end
      ampmThresholdEnabled = RFmxSpecAnMXAmpmThresholdEnabled.True;
      ampmThresholdLevel = -20; %dB
      ampmThresholdType = RFmxSpecAnMXAmpmThresholdType.Relative;
      ampmReferencePowerType = RFmxSpecAnMXAmpmReferencePowerType.Input;
      
      obj.Parent.SpecAnHandle.Ampm.Configuration.ConfigureDutAverageInputPower(...
        '', obj.Parent.DUTTargetInputPower);
      obj.Parent.SpecAnHandle.Ampm.Configuration.ConfigureReferenceWaveform(...
        '', obj.Parent.ReferenceNETWaveform, ...
        ampmreferenceWaveformIdleDurationPresent, ...
        ampmWaveformSignalType);
      obj.Parent.SpecAnHandle.Ampm.Configuration.ConfigureMeasurementInterval(...
        '', obj.Parent.AcquisitionTime);
      obj.Parent.SpecAnHandle.Ampm.Configuration.ConfigureThreshold(...
        '', ampmThresholdEnabled, ampmThresholdLevel, ampmThresholdType);
      obj.Parent.SpecAnHandle.Ampm.Configuration.ConfigureReferencePowerType(...
        '', ampmReferencePowerType);
    end
    
    function configureReferenceWaveform(obj, netWaveform)
      import NationalInstruments.RFmx.SpecAnMX.*;
      
      ampmreferenceWaveformIdleDurationPresent = RFmxSpecAnMXAmpmReferenceWaveformIdleDurationPresent.False;
      ampmWaveformSignalType = RFmxSpecAnMXAmpmSignalType.Modulated;
      obj.Parent.SpecAnHandle.Ampm.Configuration.ConfigureReferenceWaveform(...
        '', netWaveform, ...
        ampmreferenceWaveformIdleDurationPresent, ...
        ampmWaveformSignalType);
    end
    
    function result = fetch(obj)
      import NationalInstruments.RFmx.SpecAnMX.*;
      
      if obj.Verbose
        disp('Fetching AM/AM measurements')
      end
      
      [status, referencePower, measuredAMToAM, curveFitAMToAM] = ...
        obj.Parent.SpecAnHandle.Ampm.Results.FetchAMToAMTrace(...
        obj.Parent.ResultString, obj.Parent.MeasurementTimeout, ...
        [], [], []);
      x = single(referencePower);
      result.ReferencePower = x(:);
      x = single(measuredAMToAM);
      result.MeasuredAMToAM = x(:);
      
      [status, outWaveformNet] = obj.Parent.SpecAnHandle.Ampm.Results.FetchProcessedMeanAcquiredWaveform(...
        obj.Parent.ResultString, obj.Parent.MeasurementTimeout, ...
        []);
      [status, inWaveformNet] = obj.Parent.SpecAnHandle.Ampm.Results.FetchProcessedReferenceWaveform(...
        obj.Parent.ResultString, obj.Parent.MeasurementTimeout, ...
        []);
      
      outWaveform = getComplexArray(obj,outWaveformNet);
      inWaveform = getComplexArray(obj,inWaveformNet);

      refWaveform = getComplexArray(obj,obj.Parent.ReferenceNETWaveform);
      refWaveformAvgPower = 20*log10(rms(refWaveform)) + 10;
      
      scaling = false;
      if scaling == true
        % scale pa input and output waveforms to have the same
        % average power as the reference waveform
        result.OutputWaveform = scaleComplexArray(obj, outWaveform(:), refWaveformAvgPower);
        result.InputWaveform = scaleComplexArray(obj, inWaveform(:), refWaveformAvgPower);
      else
        result.OutputWaveform = outWaveform(:);
        result.InputWaveform = inWaveform(:);
      end
    
      [status, meanLinearGain] = obj.Parent.SpecAnHandle.Ampm.Results.GetMeanLinearGain(...
         obj.Parent.ResultString);
       
       result.LinearGain = meanLinearGain;
    end
  end
  
  methods (Access = protected)
    function p = getInputParser(obj)
      p = inputParser;
      p.addParameter('SignalType', 'Modulated')
    end
  end
end

