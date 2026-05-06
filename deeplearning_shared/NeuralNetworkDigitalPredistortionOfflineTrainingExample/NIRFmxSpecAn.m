classdef NIRFmxSpecAn < NIRFmxPersonality
  %NIRFmxSpecAn NI RFmx SpecAn driver
  %   SPECAN = NIRFmxSpecAn returns an NI RFmx SpecAn driver object,
  %   SPECAN. 
  %
  %   See also PowerAmplifierCharacterizationExample, helperVSTDriver,
  %   NIRFmxDriver. 
  
  %   Copyright 2020 The MathWorks, Inc.
  
  properties (Constant)
    Personality = 'SpecAn'
  end
  
  properties (GetAccess = ?Measurement, SetAccess = private)
    SpecAnHandle
  end
  
  properties (GetAccess = ?Measurement, SetAccess = private, Dependent)
    SampleRate
    AcquisitionTime
    MeasurementTimeout
    DUTTargetInputPower
  end
  
  methods
    function obj = NIRFmxSpecAn(VSA)
      % Add required .NET binaries
      NET.addAssembly('NationalInstruments.RFmx.SpecAnMX.Fx40');
      
      import NationalInstruments.RFmx.InstrMX.*;
      
      obj.VSA = VSA;
      obj.SpecAnHandle = RFmxSpecAnMXExtension.GetSpecAnSignalConfiguration(obj.VSA.InstrMXHandle);
    end
    
    function configureMeasurement(obj, measmnt, varargin)
      switch measmnt
        case 'SpecAn IQ'
          obj.Measurements{end+1} = SpecAnIQMeasurement(obj, varargin{:});
        case 'SpecAn AM/AM'
          obj.Measurements{end+1} = SpecAnAMAMMeasurement(obj, varargin{:});
        case 'SpecAn DPD'
          obj.Measurements{end+1} = SpecAnDPDMeasurement(obj, varargin{:});
      end
      configure(obj.Measurements{end})
    end
    
    function selectMeasurements(obj, measmnts, enableAllTraces)
      [measmntTypes,measmntIdx] = getMeasurementTypes(obj, measmnts);
      obj.SpecAnHandle.SelectMeasurements('', ...
        measmntTypes, enableAllTraces);
      obj.ActiveMeasurementIndices = measmntIdx;
      if length(measmnts) > 1
        obj.ResultName = 'composite';
      else
        obj.ResultName = 'result';
      end        
    end
    
    function results = run(obj)
      import NationalInstruments.RFmx.SpecAnMX.*;

      for p=obj.ActiveMeasurementIndices
        configure(obj.Measurements{p});
      end
      
      if ~isempty(obj.ActiveMeasurementIndices)
        if obj.Verbose
          disp('Starting SpecAn measurements')
        end
        
        obj.SpecAnHandle.Initiate('', obj.ResultName);
        status = obj.VSA.InstrMXHandle.WaitForAcquisitionComplete(obj.VSA.AcquisitionTimeout);
        if status
          [s1,msg] = obj.VSA.InstrMXHandle.GetErrorString(status);
          disp(msg)
        end
        
        obj.SpecAnHandle.WaitForMeasurementComplete(obj.ResultString, obj.VSA.MeasurementTimeout);
        
        for p=obj.ActiveMeasurementIndices
          results.(obj.Measurements{p}.FieldName) = ...
            obj.Measurements{p}.fetch();
        end
      else
        results = [];
      end
    end
    
    function configure(obj)
      import NationalInstruments.RFmx.SpecAnMX.*;
      
      obj.SpecAnHandle.ConfigureRF('', obj.VSA.CenterFrequency, obj.VSA.ReferenceLevel, obj.VSA.ExternalAttenuation);
      
      switch obj.VSA.TriggerSource
        case 'PXI Trigger Line 0'
          triggerSource = 'PXI_Trig0';
        case 'PXI Trigger Line 1'
          triggerSource = 'PXI_Trig1';
        case 'PXI Trigger Line 2'
          triggerSource = 'PXI_Trig2';
        case 'PXI Trigger Line 3'
          triggerSource = 'PXI_Trig3';
        case 'PXI Trigger Line 4'
          triggerSource = 'PXI_Trig4';
        case 'PXI Trigger Line 5'
          triggerSource = 'PXI_Trig5';
        case 'PXI Trigger Line 6'
          triggerSource = 'PXI_Trig6';
      end
      switch obj.VSA.TriggerEdge
        case 'Rising'
          triggerEdge = RFmxSpecAnMXDigitalEdgeTriggerEdge.Rising;
        case 'Falling'
          triggerEdge = RFmxSpecAnMXDigitalEdgeTriggerEdge.Falling;
      end
      triggerState = true; % Why would this be false?
      obj.SpecAnHandle.ConfigureDigitalEdgeTrigger('', triggerSource, ...
        triggerEdge, obj.VSA.TriggerDelay, triggerState);
    end
    
    function val = get.SampleRate(obj)
      val = obj.VSA.SampleRate;
    end
    function val = get.AcquisitionTime(obj)
      val = obj.VSA.AcquisitionTime;
    end
    function val = get.MeasurementTimeout(obj)
      val = obj.VSA.MeasurementTimeout;
    end
    function val = get.DUTTargetInputPower(obj)
      val = obj.VSA.DUTTargetInputPower;
    end

  end
  
  methods (Access=protected)
    function resultString = buildString(obj, name)
      import NationalInstruments.RFmx.SpecAnMX.*;
      
      resultString = RFmxSpecAnMX.BuildResultString(name);
    end
  end
end

