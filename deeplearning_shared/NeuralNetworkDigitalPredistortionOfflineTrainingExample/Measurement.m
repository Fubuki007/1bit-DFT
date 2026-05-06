classdef Measurement < handle
  %Measurement Base class for VST measurements
  %
  %   See also PowerAmplifierCharacterizationExample.
  
  %   Copyright 2020-2023 The MathWorks, Inc.

  properties (Abstract, Constant)
    Name
    Type
  end
  
  properties (SetAccess = protected)
    FieldName
  end
  
  properties (Access = protected)
    Parent
  end
  
  properties
    Verbose = false
  end

  methods (Abstract)
    configure(obj)
    result = fetch(obj)
  end
  
  methods (Abstract, Access = protected)
    p = getInputParser(obj);
  end
  
  methods
    function obj = Measurement(parent, varargin)
      obj.Parent = parent;

      parser = getInputParser(obj);
      parse(parser, varargin{:})
      propNames = fieldnames(parser.Results);
      for p=1:length(propNames)
        obj.(propNames{p}) = parser.Results.(propNames{p});
      end
    end
    
    function propName = get.FieldName(obj)
      propName = obj.Name;
      propName(regexp(propName, '\W*')) = '';
    end
  end
  
  methods (Access = protected)
    function complexArray = getComplexArray(~, netComplexArray)
      import NationalInstruments.*;
      if contains(class(netComplexArray), 'ComplexWaveform')
        netComplexArray = netComplexArray.GetRawData();
      end
      [i, q] = ComplexSingle.DecomposeArray(netComplexArray);
      i = single(i);
      q = single(q);
      complexArray = i + 1i * q;
    end
    
    function scaledComplexArray = scaleComplexArray(~, complexArray, desiredAveragePower)
      avgPower = 20*log10(rms(complexArray)) + 10;
      scaleFactor = 10^((desiredAveragePower - avgPower)/20);
      scaledComplexArray = complexArray * scaleFactor;
    end
  end
end

