classdef NIVSGDriver < handle
  %NIVSGDriver NI VSG driver
  %   VSG = NIVSGDriver returns an NI VSG driver object, VSG. 
  %
  %   See also PowerAmplifierCharacterizationExample, helperVSTDriver,
  %   NIRFmxDriver. 
  
  %   Copyright 2020 The MathWorks, Inc.
  
  properties
    ResourceName = 'VST_01'
    SampleRate = 1e6
    CenterFrequency = 3.6e9
    
    % DUT
    DUTTargetInputPower = 0 %5;  % dB
    ExternalAttenuation = 0 % 20  % dB

    FrequencyReference {mustBeMember(FrequencyReference,...
      {'Onboard Clock','Reference In','PXI Clock'})} = 'PXI Clock'
    MarkerEventDestination {mustBeMember(MarkerEventDestination,...
      {'PXI Trigger Line 0','PXI Trigger Line 1',...
      'PXI Trigger Line 2','PXI Trigger Line 3',...
      'PXI Trigger Line 4','PXI Trigger Line 5',...
      'PXI Trigger Line 6'})} = 'PXI Trigger Line 0'
    
    Simulated = false
    
    Verbose = false
  end
  
  properties (Access = private)
    VSG
    VSGHandle
    
    Waveforms
    ActiveWaveform = ''
  end
  
  properties (Access = private, Constant)
    MarkerIndex = 1
    MarkerDelay = 0
    
    BurstPresent = false
  end
  
  methods
    function obj = NIVSGDriver(varargin)
      %   * Open a connection to NI RFSG and get a handle
      
      p = inputParser;
      addParameter(p, 'Simulated', false);
      addParameter(p, 'ResourceName', 'VST_01');
      parse(p, varargin{:});
      obj.Simulated = p.Results.Simulated;
      obj.ResourceName = p.Results.ResourceName;

      % Add required .NET binaries
      NET.addAssembly('NationalInstruments.ModularInstruments.NIRfsg.Fx40');
      NET.addAssembly('NationalInstruments.ModularInstruments.NIRfsgPlayback.Fx40');
      
      import NationalInstruments.ModularInstruments.NIRfsg.*;
      
      if obj.Simulated
        optionsString = 'Simulate=1,DriverSetup=Model:5840';
      else
        optionsString = '';
      end
      obj.VSG = NIRfsg(obj.ResourceName, false, true, optionsString);  % IDquery, Reset
      obj.VSGHandle = obj.VSG.DangerousGetInstrumentHandle();
      
      obj.Waveforms = containers.Map;
    end
    
    function configure(obj)
      %configure Configure VSG
      %   configure(VSG) configures VSG to 
      %   * Transmit an arbitrary waveform using a script repeatedly
      %   * Generate a marker (trigger) at the start of the transmission
      %   * Download the reference waveform
      %   * Set center frequency, clock source, output power (target DUT
      %   input power + external attenuation)
      
      % Namespaces
      import NationalInstruments.ModularInstruments.NIRfsg.*;
      import NationalInstruments.ModularInstruments.NIRfsgPlayback.*;
      
      % Use arbitrary signal generator with script
      obj.VSG.Arb.GenerationMode = RfsgWaveformGenerationMode.Script;

      % Select Frequency reference source
      switch obj.FrequencyReference
        case 'Onboard Clock'
          FrequencyReferenceSource = RfsgFrequencyReferenceSource.OnboardClock;
        case 'Reference In'
          FrequencyReferenceSource = RfsgFrequencyReferenceSource.ReferenceIn;
        case 'PXI Clock'
          FrequencyReferenceSource = RfsgFrequencyReferenceSource.PxiClock;
        otherwise
          error('Unknown VSG reference clock source.');
      end
      obj.VSG.FrequencyReference.Configure(FrequencyReferenceSource, 10e6);
      
      obj.VSG.RF.ExternalGain = -obj.ExternalAttenuation;
      obj.VSG.RF.Configure(obj.CenterFrequency, obj.DUTTargetInputPower);
      
      % Set the marker trigger destination
      switch obj.MarkerEventDestination
        case 'PXI Trigger Line 0'
          vsgMarkerDestination = RfsgMarkerEventExportedOutputTerminal.PxiTriggerLine0;
        case 'PXI Trigger Line 1'
          vsgMarkerDestination = RfsgMarkerEventExportedOutputTerminal.PxiTriggerLine1;
        case 'PXI Trigger Line 2'
          vsgMarkerDestination = RfsgMarkerEventExportedOutputTerminal.PxiTriggerLine2;
        case 'PXI Trigger Line 3'
          vsgMarkerDestination = RfsgMarkerEventExportedOutputTerminal.PxiTriggerLine3;
        case 'PXI Trigger Line 4'
          vsgMarkerDestination = RfsgMarkerEventExportedOutputTerminal.PxiTriggerLine4;
        case 'PXI Trigger Line 5'
          vsgMarkerDestination = RfsgMarkerEventExportedOutputTerminal.PxiTriggerLine5;
        case 'PXI Trigger Line 6'
          vsgMarkerDestination = RfsgMarkerEventExportedOutputTerminal.PxiTriggerLine6;
      end
      markerEvent = Item(obj.VSG.DeviceEvents.MarkerEvents, obj.MarkerIndex);
      markerEvent.ExportedOutputTerminal = vsgMarkerDestination;
    end
    
    function success = startTx(obj)
      %startTx Start transmissions
      %   startTx(VSG) start the transmission of the configured waveform
      %   and check the status.
      
      import NationalInstruments.ModularInstruments.NIRfsg.*;

      obj.VSG.Initiate()
      vsgStatus = obj.VSG.CheckGenerationStatus();
      switch vsgStatus
        case RfsgGenerationStatus.InProgress
          if obj.Verbose
            disp('VSG transmission in progress')
          end
          success = true;
        case RfsgGenerationStatus.Complete
          if obj.Verbose
            disp('VSG transmission completed')
          end
          success = false;
      end
    end
    
    function success = stopTx(obj)
      %stopTx Stop transmissions
      %   stopTx(VSG) stop the transmission of the configured waveform
      %   and check the status.

      import NationalInstruments.ModularInstruments.NIRfsg.*;

      obj.VSG.Abort();
      vsgStatus = obj.VSG.CheckGenerationStatus();
      switch vsgStatus
        case RfsgGenerationStatus.InProgress
          if obj.Verbose
            disp('VSG transmission in progress')
          end
          success = false;
        case RfsgGenerationStatus.Complete
          if obj.Verbose
            disp('VSG transmission completed')
          end
          success = true;
      end
    end
    
    function release(obj)
      if ~isempty(obj.VSG)
        obj.VSG.Close()
        if obj.Verbose
          fprintf('Closed the connection to VSG.\n')
        end
      end
    end
    
    function delete(obj)
      release(obj)
    end
    
    function addWaveform(obj, waveformName, waveform)
      import NationalInstruments.ModularInstruments.NIRfsgPlayback.*;

      if isnumeric(waveform)
        netWaveform = convertToNETWaveform(obj, waveform);
      elseif isa(waveform, 'NationalInstruments.ComplexWaveform<NationalInstruments*ComplexSingle>')
        netWaveform = waveform;
        waveform = getComplexArray(obj, netWaveform);
      end
      avgPower = 20*log10(rms(waveform)) + 10;
      
      try
        NIRfsgPlayback.ClearWaveform(obj.VSGHandle, waveformName);
        remove(obj.Waveforms,waveformName);
      catch
        % If the waveform is not present, it is OK.
      end
      
      waveformInfo.NetWaveform = netWaveform;
      waveformInfo.BurstPresent = false;
      waveformInfo.AveragePower = avgPower;
      NIRfsgPlayback.DownloadUserWaveform(obj.VSGHandle, ...
        waveformName, ...
        netWaveform, ...
        waveformInfo.BurstPresent);
      obj.Waveforms(waveformName) = waveformInfo;
      
    end
    
    function setWaveformSampleRate(obj, waveformName, fs)
      import NationalInstruments.ModularInstruments.NIRfsgPlayback.*;
      
      NIRfsgPlayback.StoreWaveformSampleRate(obj.VSGHandle, ...
        waveformName, fs);
    end
    
    function setWaveformSignalBandwidth(obj, waveformName, bw)
      import NationalInstruments.ModularInstruments.NIRfsgPlayback.*;
      
      NIRfsgPlayback.StoreWaveformSignalBandwidth(obj.VSGHandle, ...
        waveformName, bw);
    end
    
    function setWaveformPAPR(obj, waveformName, papr)
      import NationalInstruments.ModularInstruments.NIRfsgPlayback.*;
      
      NIRfsgPlayback.StoreWaveformPapr(obj.VSGHandle, ...
        waveformName, papr);

      waveformInfo = obj.Waveforms(waveformName);
      waveformInfo.PAPR = papr;
      obj.Waveforms(waveformName) = waveformInfo;
    end
      
    function setWaveformRuntimeScaling(obj, waveformName, scaling)
      import NationalInstruments.ModularInstruments.NIRfsgPlayback.*;
      
      NIRfsgPlayback.StoreWaveformRuntimeScaling(obj.VSGHandle, ...
        waveformName, scaling);
    end
    
    function clearWaveform(obj, waveformName)
      import NationalInstruments.ModularInstruments.NIRfsgPlayback.*;

      try
        NIRfsgPlayback.ClearWaveform(obj.VSGHandle, waveformName);
        remove(obj.Waveforms,waveformName);
      catch me
        warning(me.message)
      end
    end
    
    function activateWaveform(obj, waveformName)
      import NationalInstruments.ModularInstruments.NIRfsgPlayback.*;
      
      % Repeat <referenceWaveformName> forever. Generate a trigger at the 0th
      % sample [marker1(0)].
      referenceWaveformScript = ...
        sprintf(['script refScript '...
        'repeat forever '...
        'generate %s marker%d(%d) '...
        'end repeat ' ...
        'end script'], ...
        waveformName, ...
        obj.MarkerIndex, ...
        obj.MarkerDelay);      
      
      NIRfsgPlayback.SetScriptToGenerateSingleRfsg(obj.VSGHandle, ...
        referenceWaveformScript);
      
      obj.ActiveWaveform = waveformName;
    end
    
    function netWaveform = getNetWaveform(obj, waveformName)
      if nargin < 2
        waveformName = obj.ActiveWaveform;
      end
      waveformInfo = obj.Waveforms(waveformName);
      netWaveform = waveformInfo.NetWaveform;
    end
    
    function papr = getWaveformPAPR(obj, waveformName)
      import NationalInstruments.ModularInstruments.NIRfsgPlayback.*;

      if nargin < 2
        waveformName = obj.ActiveWaveform;
      end
      [status,papr]=NIRfsgPlayback.RetrieveWaveformPapr(...
        obj.VSGHandle, waveformName);
    end
    
    function avgPower = getWaveformAveragePower(obj, waveformName)
      if nargin < 2
        waveformName = obj.ActiveWaveform;
      end
      waveformInfo = obj.Waveforms(waveformName);
      avgPower = waveformInfo.AveragePower;
    end
  end
  
  methods (Access = private)
    function netWaveform = convertToNETWaveform(obj, waveform)
      txI = real(waveform);
      txQ = imag(waveform);
      netComplexArray = NationalInstruments.ComplexSingle.ComposeArray(txI, txQ);
      netWaveform = NET.createGeneric('NationalInstruments.ComplexWaveform', {'NationalInstruments.ComplexSingle'}, 0, netComplexArray.Length);
      netWaveform.Append(netComplexArray);
      netWaveform.PrecisionTiming = NationalInstruments.PrecisionWaveformTiming.CreateWithRegularInterval(NationalInstruments.PrecisionTimeSpan(1/obj.SampleRate));
    end
    
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
  end
end

