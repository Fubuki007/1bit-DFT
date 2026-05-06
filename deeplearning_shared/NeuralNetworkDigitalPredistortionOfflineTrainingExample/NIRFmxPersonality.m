classdef NIRFmxPersonality < handle
  %NIRFmxPersonality NI RFmx personality base class
  %
  %   See also PowerAmplifierCharacterizationExample, helperVSTDriver,
  %   NIRFmxDriver, NIRFmxSpecAn. 
  
  %   Copyright 2020 The MathWorks, Inc.

  properties (Constant, Abstract)
    Personality
  end
  
  properties
    Measurements = {}
    ReferenceNETWaveform
    
    Verbose = false
  end
  
  properties (GetAccess = {?Measurement,?NIRFmxPersonality}, SetAccess = protected)
    ResultString = ''
  end
  
  properties (Access = protected)
    VSA
    ActiveMeasurementIndices = []

    ResultName = ''
  end
  
  methods (Abstract)
    configureMeasurement(obj, measmnt, varargin)
  end
  
  methods (Abstract, Access=protected)
    resultString = buildString(obj, name)
  end
  
  methods
    function set.ResultName(obj, name)
      obj.ResultString = buildString(obj, name); %#ok<MCSUP>
      obj.ResultName = name;
    end
    
    function set.ReferenceNETWaveform(obj, netWaveform)
      for p=1:length(obj.Measurements)
        configureReferenceWaveform(obj.Measurements{p}, netWaveform);
      end
      obj.ReferenceNETWaveform = netWaveform;
    end
    
    function removeMeasurements(obj)
      obj.Measurements = {};
    end
  end
  
  methods (Access = protected)
    function [measmntTypes,measmntIdx] = getMeasurementTypes(obj, measments)
      measmntTypes = [];
      numMeasurements = length(obj.Measurements);
      measmntIdx = [];
      for p=1:length(measments)
        for q=1:numMeasurements
          if strcmp([obj.Personality ' ' obj.Measurements{q}.Name], measments{p})
            if isempty(measmntTypes)
              measmntTypes = obj.Measurements{q}.Type;
            else
              measmntTypes = bitor(measmntTypes, obj.Measurements{q}.Type);
            end
            measmntIdx(end+1) = q; %#ok<AGROW>
            break
          end
        end
      end
    end
  end
end