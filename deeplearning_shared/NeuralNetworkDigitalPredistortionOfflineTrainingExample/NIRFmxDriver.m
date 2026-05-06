classdef NIRFmxDriver < handle
  %NIRFmxDriver NI RFmx driver
  %   RFMX = NIRFmxDriver returns an NI RFmx driver object,
  %   RFMX. 
  %
  %   See also PowerAmplifierCharacterizationExample, helperVSTDriver,
  %   NIVSTDriver, NIVSGDriver. 
  
  %   Copyright 2020 The MathWorks, Inc.
  
  properties
    ResourceName = 'VST_01'

    SampleRate = 1e6
    CenterFrequency = 3.6e9
    ReferenceLevel = 0
    ExternalAttenuation = 0
    
    FrequencyReference {mustBeMember(FrequencyReference,...
      {'Onboard Clock','Reference In','PXI Clock'})} = 'PXI Clock'
    
    TriggerSource {mustBeMember(TriggerSource,...
      {'PXI Trigger Line 0','PXI Trigger Line 1',...
      'PXI Trigger Line 2','PXI Trigger Line 3',...
      'PXI Trigger Line 4','PXI Trigger Line 5',...
      'PXI Trigger Line 6'})} = 'PXI Trigger Line 0'
    TriggerEdge {mustBeMember(TriggerEdge,...
      {'Rising', 'Falling'})} = 'Rising'
    TriggerDelay = 0
    
    AcquisitionTimeout = 10
    AcquisitionTime = 1e-3
    
    MeasurementTimeout = 10

    
    % DUT
    DUTTargetInputPower = 0 %5;  % dB
    
    Simulated = false
    
    Verbose = false
  end
  
  properties (Dependent)
    ReferenceNETWaveform
  end
  
  properties (GetAccess = {?NIRFmxDriver,?NIRFmxPersonality}, SetAccess = private)
    InstrMXHandle  % Handle for InstrMX personality (main one)
    SpecAn         % Spectrum Analyzer driver for MATLAB
  end

  methods
    function obj = NIRFmxDriver(varargin)
      p = inputParser;
      addParameter(p, 'Simulated', false);
      addParameter(p, 'ResourceName', 'VST_01');
      parse(p, varargin{:});
      obj.Simulated = p.Results.Simulated;
      obj.ResourceName = p.Results.ResourceName;

      % Add required .NET binaries
      NET.addAssembly('NationalInstruments.RFmx.InstrMX.Fx40');
      NET.addAssembly('NationalInstruments.RFmx.SpecAnMX.Fx40');

      import NationalInstruments.RFmx.InstrMX.*;

      if obj.Simulated
        optionsString = 'Simulate=1,DriverSetup=Model:5840';
      else
        optionsString = '';
      end
      obj.InstrMXHandle = RFmxInstrMX(obj.ResourceName, optionsString);
      
      obj.SpecAn = NIRFmxSpecAn(obj);
    end
    
    function set.ReferenceNETWaveform(obj, netWaveform)
      obj.SpecAn.ReferenceNETWaveform = netWaveform;
    end

    function netWaveform = get.ReferenceNETWaveform(obj)
      netWaveform = obj.SpecAn.ReferenceNETWaveform;
    end

    function configure(obj)
      import NationalInstruments.RFmx.SpecAnMX.*;
      
      % Select Frequency reference source
      switch obj.FrequencyReference
        case 'Onboard Clock'
          FrequencyReferenceSource = 'OnboardClock';
        case 'Reference In'
          FrequencyReferenceSource = 'RefIn';
        case 'PXI Clock'
          FrequencyReferenceSource = 'PXI_CLK';
        otherwise
          error('Unknown VSA reference clock source.');
      end
      % 10e6 is the only supported value
      obj.InstrMXHandle.ConfigureFrequencyReference('', FrequencyReferenceSource, 10e6);

      configure(obj.SpecAn)
    end
    
    function release(obj)
      if ~isempty(obj.InstrMXHandle)
        obj.InstrMXHandle.Close()
        if obj.Verbose
          fprintf('Closed the connection to VSA.\n')
        end
      end
    end

    function delete(obj)
      release(obj)
    end
    
    function configureMeasurement(obj, measmnt, varargin)
      configureMeasurement(obj.SpecAn, measmnt, varargin{:})
    end
    
    function selectMeasurements(obj, measmnts, enableAllTraces)
      specAnMeas = contains(measmnts, 'SpecAn');
      selectMeasurements(obj.SpecAn, measmnts(specAnMeas), enableAllTraces)
    end
    
    function removeMeasurements(obj)
      removeMeasurements(obj.SpecAn)
    end
    
    function results = run(obj)
      results = run(obj.SpecAn);
    end
  end
  
  methods (Access = private)
    function complexArray = getComplexArray(~, netWaveform)
      import NationalInstruments.*;
      netComplexArray = netWaveform.GetRawData();
      [i, q] = ComplexSingle.DecomposeArray(netComplexArray);
      i = single(i);
      q = single(q);
      complexArray = i + 1j * q;
    end
  end
end

