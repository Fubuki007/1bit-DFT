classdef helperNNDPDPowerAmplifier < matlab.System 

  properties (Nontunable)
    DataSource (1,1) string ...
      {mustBeMember(DataSource,["NI VST","Simulated PA","Saved data"])} ...
      = "Simulated PA"
    SampleRate = 1e9
  end

  properties (Hidden)
    TargetInputPower = 5  % dBm
  end

  properties (Access=private)
    VST
    PANeuralNetwork
    SimulatedPAInputProcessor
    SimulatedPAScalingFactor
    SimulatedPAMemoryDepth
    SimulatedPANonlinearityOrder
    SavedPAOutput
    SavedDPDInput
  end

  methods
    function obj = helperNNDPDPowerAmplifier(varargin)   
      setProperties(obj, nargin, varargin{:}); 
    end
  end

  methods (Access=protected)
    function setupImpl(obj)
      switch obj.DataSource
        case "NI VST"
          obj.VST = helperVSTDriver('VST_01');
          obj.VST.DUTExpectedGain     = 29;                % dB
          obj.VST.ExternalAttenuation = 30;                % dB
          obj.VST.DUTTargetInputPower = obj.TargetInputPower;
          obj.VST.CenterFrequency     = 3.7e9;             % Hz
        case "Simulated PA"
          load paModelNN.mat netPA memDepthPA nonlinearDegreePA scalingFactorPA
          obj.PANeuralNetwork = netPA;
          obj.SimulatedPAInputProcessor = helperNNDPDInputPreprocessor(memDepthPA,nonlinearDegreePA);
          obj.SimulatedPAScalingFactor = scalingFactorPA;
          obj.SimulatedPAMemoryDepth = memDepthPA;
          obj.SimulatedPANonlinearityOrder = nonlinearDegreePA;
        case "Saved data"
          trainDataFile = "nndpdTrainingDataOct23.mat";
          if exist(trainDataFile,"file")
            load(trainDataFile,"txWaveTrain","txWaveVal", ...
              "txWaveTest","paOutputTrain","paOutputVal","paOutputTest")
            obj.SavedDPDInput(:,1) = txWaveTrain(1:10);
            obj.SavedDPDInput(:,end+1) = txWaveVal(1:10);
            obj.SavedDPDInput(:,end+1) = txWaveTest(1:10);

            obj.SavedPAOutput{1} = paOutputTrain;
            obj.SavedPAOutput{end+1} = paOutputVal;
            obj.SavedPAOutput{end+1} = paOutputTest;
          end
          testDataFile = "nndpdTestData.mat";
          if exist(testDataFile,"file")
            load(testDataFile,"dpdOutNN","paOutputNN", ...
              "dpdOutMP","paOutputMP")
            obj.SavedDPDInput(:,end+1) = dpdOutMP(1:10);
            obj.SavedDPDInput(:,end+1) = dpdOutNN(1:10);

            obj.SavedPAOutput{end+1} = paOutputMP;
            obj.SavedPAOutput{end+1} = paOutputNN;
          end
          projectionDataFile = "nndpdProjectionDataOct23.mat";
          if exist(projectionDataFile,"file")
            load(projectionDataFile, "paInputNNFineTunedFinal", ...
              "paInputNNFineTunedVec", "paInputNNProjectedFinal", ...
              "paInputNNProjectedVec", "paOutputNNFineTunedFinal", ...
              "paOutputNNFineTunedVec", "paOutputNNProjectedFinal", ...
              "paOutputNNProjectedVec");
            obj.SavedDPDInput(:,end+1) = paInputNNProjectedFinal(1:10);
            obj.SavedDPDInput(:,end+1) = paInputNNFineTunedFinal(1:10);

            obj.SavedPAOutput{end+1} = paOutputNNProjectedFinal;
            obj.SavedPAOutput{end+1} = paOutputNNFineTunedFinal;

            idx = length(obj.SavedPAOutput);
            for p=1:size(paInputNNFineTunedVec,2)
              obj.SavedDPDInput(:,idx+p) = paInputNNFineTunedVec(:,p);
              obj.SavedPAOutput{idx+p} = paOutputNNFineTunedVec(:,p);
            end
            idx = length(obj.SavedPAOutput);
            for p=1:size(paInputNNProjectedVec,2)
              obj.SavedDPDInput(:,idx+p) = paInputNNProjectedVec(:,p);
              obj.SavedPAOutput{idx+p} = paOutputNNProjectedVec(:,p);
            end
          end
      end
    end

    function out = stepImpl(obj,in)
      switch obj.DataSource
        case "NI VST"
          out = helperNNDPDPAMeasure(in,obj.SampleRate,obj.VST);
        case "Simulated PA"
          X = obj.SimulatedPAInputProcessor(in*obj.SimulatedPAScalingFactor);
          Y = predict(obj.PANeuralNetwork,X);
          out = complex(Y(:,1), Y(:,2)) / obj.SimulatedPAScalingFactor;
        case "Saved data"
          idx = find(abs(imag(sum(obj.SavedDPDInput(1:10,:).*conj(in(1:10))))) < sqrt(eps));
          if ~isempty(idx)
            out = obj.SavedPAOutput{idx};
          else
            error("Cannot find saved output.")
          end
      end
    end

    function releaseImpl(obj)
      switch obj.DataSource
        case "NI VST"
          release(obj.VST);
        case "Simulated PA"
          release(obj.SimulatedPAInputProcessor)
        case "Saved data"
          obj.SavedDPDInput = [];
          obj.SavedPAOutput = {};
      end
    end

    function out = infoImpl(obj)
      switch obj.DataSource
        case "NI VST"
          out = struct();
        case "Simulated PA"
          out = struct("MemoryDepth",obj.SimulatedPAMemoryDepth, ...
            "NonlinearityOrder",obj.SimulatedPANonlinearityOrder);
        case "Saved data"
          out = struct();
      end      
    end
  end
end