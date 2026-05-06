classdef NIVSTDriver < handle
  %NIVSTDriver NI VST driver
  %   VST = NIVSTDriver returns an NI VST driver object, VST.
  %
  %   See also PowerAmplifierCharacterizationExample, helperVSTDriver,
  %   NIRFmxDriver, NIVSGDriver. 
  
  %   Copyright 2020-2023 The MathWorks, Inc.
  
  properties
    VSA
    VSG

    DUTExpectedGain = 30
    DUTExpectedGainAccuracy = 1
  end
  
  % VSG Properties
  properties (Dependent)
    SampleRate
    CenterFrequency
    
    % DUT
    DUTTargetInputPower
    
    Simulated
  end
  
  properties (Access = private, Constant)
  end
  
  methods
    function obj = NIVSTDriver(resourceName, varargin)
      p = inputParser;
      addRequired(p, 'ResourceName')
      addParameter(p, 'Simulated', false);
      parse(p, resourceName, varargin{:});
      obj.Simulated = p.Results.Simulated;
      
      try
        obj.VSG = NIVSGDriver('Simulated', p.Results.Simulated, ...
          'ResourceName', p.Results.ResourceName);
      catch me
        if strcmp(me.identifier,'MATLAB:NET:AddAssembly:GACLoadError')
          error(['NI .NET drivers cannot be found. Install required ' ...
            'libraries as described in Power Amplifier Characterization ' ...
            'example.'])
        elseif ~ispc()
          error(['Unsupported platform. NI .NET drivers are supported ' ...
            'only on Windows OS.'])
        end
      end
      try 
        obj.VSA = NIRFmxDriver('Simulated', p.Results.Simulated, ...
          'ResourceName', p.Results.ResourceName);
      catch me
        if strcmp(me.identifier,'MATLAB:NET:AddAssembly:GACLoadError')
          error(['NI .NET drivers cannot be found. Install required ' ...
            'libraries as described in Power Amplifier Characterization ' ...
            'example.'])
        elseif ~ispc()
          error(['Unsupported platform. NI .NET drivers are supported ' ...
            'only on Windows OS.'])
        elseif contains(me.message, 'Session already exists')
          vars = evalin('base','whos');
          for k=1:length(vars)
            if evalin('base',['isa(' vars(k).name ', ''helperVSTDriver'')'])
              evalin('base', ['release(' vars(k).name ')'])
              obj.VSA = NIRFmxDriver('Simulated', p.Results.Simulated);
            end
          end
        else
          rethrow(me)
        end
      end
    end

    % Expose common properties
    function set.SampleRate(obj, value)
      obj.VSG.SampleRate = value;
      obj.VSA.SampleRate = value;
    end
    function value = get.SampleRate(obj)
      value1 = obj.VSG.SampleRate;
      value2 = obj.VSA.SampleRate;
      if value1 == value2
        value = value1;
      else
        error('Unexpected center frequency setting')
      end
    end
    function set.CenterFrequency(obj, value)
      obj.VSG.CenterFrequency = value;
      obj.VSA.CenterFrequency = value;
    end
    function value = get.CenterFrequency(obj)
      value1 = obj.VSG.CenterFrequency;
      value2 = obj.VSA.CenterFrequency;
      if value1 == value2
        value = value1;
      else
        error('Unexpected center frequency setting')
      end
    end
    function set.Simulated(obj, value)
      obj.VSG.Simulated = value;
      obj.VSA.Simulated = value;
    end
    function value = get.Simulated(obj)
      value1 = obj.VSG.Simulated;
      value2 = obj.VSA.Simulated;
      if value1 == value2
        value = value1;
      else
        error('Unexpected state for Simulated mode.')
      end
    end
    function set.DUTTargetInputPower(obj, value)
      obj.VSG.DUTTargetInputPower = value;
      obj.VSA.DUTTargetInputPower = value;
    end
    function value = get.DUTTargetInputPower(obj)
      value1 = obj.VSG.DUTTargetInputPower;
      value2 = obj.VSA.DUTTargetInputPower;
      if value1 == value2
        value = value1;
      else
        error('Unexpected state for Simulated mode.')
      end
    end
    
    function configure(obj)
      configure(obj.VSG);
      obj.VSA.ReferenceLevel = getDUTMaxOutputPower(obj);
      configure(obj.VSA);
    end
    
    function success = startTx(obj)
      success = startTx(obj.VSG);
    end
    
    function success = stopTx(obj)
      success = stopTx(obj.VSG);
    end
    
    function results = runRx(obj)
      results = run(obj.VSA);
    end
    
    function results = run(obj)
      success = startTx(obj.VSG);
      results = run(obj.VSA);
      success = stopTx(obj.VSG);
    end
    
    function addWaveform(obj, waveformName, waveform)
      addWaveform(obj.VSG, waveformName, waveform)
      
      activateWaveform(obj, waveformName)
    end

    function clearWaveform(obj, waveformName)
      clearWaveform(obj.VSG, waveformName)
    end    
    
    function activateWaveform(obj, waveformName)
      activateWaveform(obj.VSG, waveformName)
      
      obj.VSA.ReferenceNETWaveform = getNetWaveform(obj.VSG, waveformName);
    end

    function setWaveformSampleRate(obj, waveformName, fs)
      setWaveformSampleRate(obj.VSG, waveformName, fs)
    end
    
    function setWaveformSignalBandwidth(obj, waveformName, bw)
      setWaveformSignalBandwidth(obj.VSG, waveformName, bw)
    end
    
    function setWaveformPAPR(obj, waveformName, papr)
      setWaveformPAPR(obj.VSG, waveformName, papr)
    end
      
    function setWaveformRuntimeScaling(obj, waveformName, scaling)
      setWaveformRuntimeScaling(obj.VSG, waveformName, scaling)
    end
    
    function configureMeasurement(obj, measmnt, varargin)
      configureMeasurement(obj.VSA, measmnt, varargin{:})
    end
    
    function selectMeasurements(obj, measmnts, enableAllTraces)
      selectMeasurements(obj.VSA, measmnts, enableAllTraces)
    end
    
    function removeMeasurements(obj)
      removeMeasurements(obj.VSA)
    end
    
    function release(obj)
      if isa(obj.VSG,'NIVSGDriver')
        release(obj.VSG)
      end
      if isa(obj.VSA,'NIRFmxDriver')
        release(obj.VSA)
      end
    end
    
    function delete(obj)
      release(obj)
    end
  end
  
  methods (Access = protected)
    function outPower = getDUTMaxOutputPower(obj)
        outPower = obj.DUTTargetInputPower ...
        + obj.DUTExpectedGain ...
        + obj.DUTExpectedGainAccuracy ...
        + getWaveformPAPR(obj.VSG);
    end
  end
  
end

