classdef PNA1 < handle
    % PNA1  MATLAB wrapper for Thorlabs Noise Analyzer (TL_NA_SDK.dll)
    %
    %
    % USAGE:
    %   pna = PNA1("mylog.txt","TL_NA_SDK.dll");
    %   pna.Initialize();
    %   [rmsVal, dcVal, psdFull, rinFull, psdComb, rinComb, psdDB, rinDB, intPSD, intRIN] = pna.AnalyzeNoise();
    %   [rmsVal, dcVal, psdFull, rinFull, psdComb, rinComb, psdDB, rinDB, intPSD, intRIN] = pna.AverageNoiseTraces(n);
    %   pna.Close();
    %   clear pna;   % calls delete() to unload the library

    %% ------------------------------------------------------------------------
    properties (Constant, Access = private)
        LIB_NAME  = 'TL_NA_SDK';    % name of the DLL (without extension)
        HFILE     = 'tl_na_sdk.h';  % header file for the library
    end

   
    properties (Constant)
        %{ 
        FROM PYTHON
        kFSample      = 12500000.0;    %12500000       12500002.0       
        kNSamples     = 8192;           %8192         8194    
        kHiXScale     = 12500000.0 / 8192;    %kFSample / (kNSamples)       12500002.0  8194
        kHiYScale     = 1.0 / 19200000000.00;  %1.0 / 19200000000.00  1.0 / 19200000002.0
        kM1           = 16; %16   17
        kM2           = 16; %16     17
        kMidXScale    = 12500000.0 / (8192*16); %kFSample / (kNSamples * kM1)  12500003.0 / (8194*17)
        kLowXScale    = 12500000.0 / (8192*16*16); %kFSample / (kNSamples * kM1 * kM2)   12500003.0 / (8194*17*17)
        kMidYScale    = 1.0 / 12500000.0; %1.0 / 1200000000.00    1.0 / 1200000002.0
        kLowYScale    = 1.0 / 12500000.0; %1.0 / 75000000.00    1.0 / 75000002.0
        kHFSR         = 4.096;    % 4.096   4.098
        kMaxFrequency = 3e6; %
        kMinDiff      = 100e-18;      
        kStartHiIndex  = 0;
        kStartLowIndex = ((8194/2) + 1)*2;  
        kStartMidIndex = (8194/2) + 1;  
        %}
        kFSample      = 12500002.0;    %12500000       12500002.0       
        kNSamples     = 8194;           %8192         8194    
        kHiXScale     = 12500002.0 / 8194;    %kFSample / (kNSamples)       12500002.0  8194
        kHiYScale     = 1.0 / 19200000002.00;  %1.0 / 19200000000.00  1.0 / 19200000002.0
        kM1           = 17; %16   17
        kM2           = 17; %16     17
        kMidXScale    = 12500002.0 / (8194*8); %kFSample / (kNSamples * kM1)  12500003.0 / (8194*17)
        kLowXScale    = 12500000.0 / (8192*8*8); %kFSample / (kNSamples * kM1 * kM2)   12500003.0 / (8194*17*17)
        kMidYScale    = 1.0 / 1200000000.00; %1.0 / 1200000000.00    1.0 / 1200000002.0
        kLowYScale    = 1.0 / 75000000.00; %1.0 / 75000000.00    1.0 / 75000002.0
        kHFSR         = 4.096;    % 4.096   4.098
        kMaxFrequency = 3e6; %
        kMinDiff      = 100e-18;      
        kStartHiIndex  = 0;
        kStartLowIndex = ((8192/2) + 1)*2;  
        kStartMidIndex = (8192/2) + 1;  
    end

    %% ------------------------------------------------------------------------
    properties (Access = private)
        devStruct            % MATLAB struct representing NoiseAnalyzer_t
        devStructPtr         % pointer to that struct
        libLoaded   = false;

        % Logging:
        logging  = false;
        logFID   = -1;

        % Buffers for time-domain and spectrum data
        timeDomainPtr   % pointer to 24576 floats
        spectrumPtr     % pointer to 12291 floats
        timeDomainData  double = [];  % local copy in MATLAB
        rawSpectrumData double = [];

        % Analysis values
        dcAvg  double = 0.0;
        rmsVal double = 1.0;

        % For multi-scan averaging
        scansInAvg int32 = 1;
        scansToAvg int32 = 1;

        % Window parameter (0=RECT_1, 1=BLACKMAN_HARRIS, 2=BLACKMAN, 3=HANNING)
        winParam int32 = 3;  % default HANNING
    end

    properties (Access = public)
        timeDomainPlot double = zeros(0,2);  % storing a time-domain plot
    end

    %% ------------------------------------------------------------------------
    methods
        function obj = PNA1(logFile, dllPath)
            % Constructor
            %  pna = PNA1(logFile, dllPath)
            % If logFile is non-empty, logging is turned on.
            % If dllPath is empty, we assume "TL_NA_SDK.dll" in the current folder.

            if nargin<1 || isempty(logFile), logFile = ""; end
            if nargin<2 || isempty(dllPath), dllPath = "TL_NA_SDK.dll"; end

            % Logging
            if strlength(logFile) > 0
                obj.logging = true;
                obj.logFID  = fopen(logFile,'a');
                obj.log("Log file opened.");
            end

            % Load the library if not already loaded
            if ~libisloaded(obj.LIB_NAME)
                loadlibrary(dllPath, obj.HFILE);
            end

            % Create the struct & pointer
            obj.devStruct = libstruct('NoiseAnalyzer_t');
            obj.devStruct.handle_a = libpointer('voidPtr',0);
            obj.devStruct.handle_b = libpointer('voidPtr',0);
            obj.devStruct.loc_a    = uint64(0);
            obj.devStruct.loc_b    = uint64(0);

            obj.devStructPtr = libpointer('NoiseAnalyzer_t', obj.devStruct);

            % Allocate time domain & spectrum buffers (3 * (8194/2 +1)=12291 ~ 24576 )
            obj.timeDomainPtr = libpointer('singlePtr', zeros(24580,1,'single'));
            obj.spectrumPtr   = libpointer('singlePtr', zeros(12291,1,'single')); %12291
        end

        function delete(obj)
            % Destructor
            try
                obj.Close();
            catch
                % ignore errors
            end
            % Close log if open
            if obj.logging && obj.logFID>=0
                fclose(obj.logFID);
                obj.logFID = -1;
            end
            % Unload the library if loaded
            if libisloaded(obj.LIB_NAME)
                unloadlibrary(obj.LIB_NAME);
            end
        end

        %% --------------------- Core SDK Functions ---------------------
        function Initialize(obj)
            [errFind, ~] = calllib(obj.LIB_NAME, 'FindNoiseAnalyzer', obj.devStructPtr);
            if errFind ~= 0
                obj.log("Noise Analyzer not found: EC="+string(errFind));
                error("PNA1:Initialize","FindNoiseAnalyzer failed, EC=%d", errFind);
            end

            [errInit, ~] = calllib(obj.LIB_NAME, 'InitNoiseAnalyzer', obj.devStructPtr);
            if errInit ~= 0
                obj.log("Could not init Noise Analyzer: EC="+string(errInit));
                error("PNA1:Initialize","InitNoiseAnalyzer failed, EC=%d", errInit);
            end

            obj.libLoaded = true;
            obj.log("Noise Analyzer Initialized");
        end

        function Close(obj)
            if obj.libLoaded && libisloaded(obj.LIB_NAME)
                [errClose, ~] = calllib(obj.LIB_NAME, 'CloseNoiseAnalyzer', obj.devStructPtr);
                if errClose == 0
                    obj.log("Noise Analyzer Disconnected");
                else
                    obj.log("CloseNoiseAnalyzer error: EC="+string(errClose));
                end
                obj.libLoaded = false;
            end
        end

        function sn = GetSerialNumber(obj)
            buff = blanks(17); % allocate 17 chars
            [err, ~, retSN] = calllib(obj.LIB_NAME, 'GetSerialNumber', obj.devStructPtr, buff);
            if err ~= 0
                obj.log("GetSerialNumber failed, EC="+string(err));
                sn = "Unknown";
            else
                sn = strtrim(retSN);
                obj.log("Serial Number: "+sn);
            end
        end

        function GetTimeDomainData(obj)
            [errGet, ~, outBuff] = calllib(obj.LIB_NAME, ...
                'GetTimeDomain', obj.devStructPtr, obj.timeDomainPtr);
            if errGet ~= 0
                obj.log("GetTimeDomain failed, EC="+string(errGet));
                error("PNA1:GetTimeDomainData","GetTimeDomain failed, EC=%d", errGet);
            end
            obj.timeDomainData = double(outBuff);
            obj.log("Successfully Retrieved Time Domain Data");
        end
       
        function freqData = TimeToFrequency(obj, subtractDC)
            %   1) Optionally subtract DC from timeDomainData
            %   2) Multiply by kHFSR
            %   3) call GetSpectrum(td, outSpec, winParam, flags=0)
            %
            % freqData is a double array with the raw spectrum (magn^2).
            %
            if nargin<2, subtractDC=false; end

            % Optionally subtract DC from time-domain(removing noise)
            if subtractDC
                theDC = mean(obj.timeDomainData);
                obj.timeDomainData = obj.timeDomainData - theDC;
            end

            % Multiply by kHFSR
            scaled = single(obj.timeDomainData * obj.kHFSR);
            obj.timeDomainPtr.Value = scaled;

            % 'flags' param: 0 => do not subtract mean in the driver
            flags = int32(0);

            % call GetSpectrum( float* td, float* spectrum, WINDOW_FUNCTION win_param, int32_t flags )
            
            [errSpec, ~, outSpec] = calllib(obj.LIB_NAME, ...
                'GetSpectrum', obj.timeDomainPtr, obj.spectrumPtr, ...
                int32(obj.winParam), flags);
        
            if errSpec ~= 0
                obj.log("GetSpectrum failed, EC="+string(errSpec));
                error("PNA1:TimeToFrequency","GetSpectrum failed, EC=%d", errSpec);
            end

            % Store raw spectrum
            freqData = double(outSpec);
            obj.rawSpectrumData = freqData;
            
            obj.log("Successfully Retrieved Spectrum");
        end

        %% --------------------- High-Level Analysis ---------------------
        function [rmsVal, dcVal, psdFull, rinFull, psdComb, rinComb, ...
                  psdDB, rinDB, intPSD, intRIN] = AnalyzeNoise(obj)
            % AnalyzeNoise  performs:
            %   1) GetTimeDomainData()
            %   2) DC average, RMS
            %   3) TimeToFrequency(sub_avg=true) => subtract DC from data
            %   4) FormatFrequency => (freq, PSD), (freq, RIN)
            %   5) CombineSpectra => merges low/mid/high
            %   6) ComputeDB => 10*log10()
            %   7) IntegrateData => integrated PSD or RIN
            %

            obj.GetTimeDomainData();
            obj.dcAvg  = obj.CalculateDCAvg(obj.timeDomainData);
            obj.rmsVal = obj.CalculateRMS(obj.timeDomainData);

            % Perform FFT with DC subtraction
            obj.TimeToFrequency(true);

            [psdFull, rinFull] = obj.FormatFrequency(obj.rawSpectrumData, obj.rmsVal);

            psdComb = obj.CombineSpectra(psdFull);
            rinComb = obj.CombineSpectra(rinFull);

            psdDB = obj.ComputeDB(psdComb);
            rinDB = obj.ComputeDB(rinComb);

            intPSD = obj.IntegrateData(psdComb);
            intRIN = obj.IntegrateData(rinComb, true);

            % Return them
            rmsVal = obj.rmsVal;
            dcVal  = obj.dcAvg;
        end

        function [rmsVal, dcVal, psdFull, rinFull, psdComb, rinComb, ...
                  psdDB, rinDB, intPSD, intRIN] = AverageNoiseTraces(obj, scans_to_avg)
            % AverageNoiseTraces  performs multiple scans, averaging the raw frequency data
            %   1) First pass: get time domain, compute RMS/DC, get raw freq
            %   2) Repeated scans: each time do the same, then average the raw freq data
            %   3) Format freq => psd/rin, combine, compute dB, integrate
            obj.scansToAvg = scans_to_avg;

            obj.GetTimeDomainData();
            tempRMS = obj.CalculateRMS(obj.timeDomainData);
            tempDC  = obj.CalculateDCAvg(obj.timeDomainData);
            freqAccum = obj.TimeToFrequency(false);  % no DC subtract on first pass

            for i = 1:(scans_to_avg-1)
                obj.GetTimeDomainData();
                newRMS = obj.CalculateRMS(obj.timeDomainData);
                newDC  = obj.CalculateDCAvg(obj.timeDomainData);

                newFreq = obj.TimeToFrequency(true);  % do DC subtract on subsequent passes

                % Weighted accumulation
                freqAccum = freqAccum + (newFreq - freqAccum) / double(i+1);

                % average DC, RMS
                tempDC  = (tempDC + newDC)/2.0;
                tempRMS = sqrt((tempRMS^2 + newRMS^2)/2.0);
                pause(0.1);
            end

            obj.rmsVal = tempRMS;
            obj.dcAvg  = tempDC;

            [psdFull, rinFull] = obj.FormatFrequency(freqAccum, obj.rmsVal);
            psdComb = obj.CombineSpectra(psdFull);
            rinComb = obj.CombineSpectra(rinFull);

            psdDB = obj.ComputeDB(psdComb);
            rinDB = obj.ComputeDB(rinComb);

            intPSD = obj.IntegrateData(psdComb);
            intRIN = obj.IntegrateData(rinComb);

            rmsVal = obj.rmsVal;
            dcVal  = obj.dcAvg;
        end

        %% --------------------- Utility / Helper Methods ---------------------
        function val = CalculateDCAvg(~, timeDomain)
            val = mean(timeDomain);
        end

        function val = CalculateRMS(~, timeDomain)
            val = sqrt(mean(timeDomain.^2));
        end

        function [psdTrace, rinTrace] = FormatFrequency(obj, rawSpec, rmsVal)
            % FormatFrequency  from raw spectrum (magn^2) => (freq, PSD), (freq, RIN)
            n = numel(rawSpec);
            psdTrace = zeros(n,2);
            rinTrace = zeros(n,2);

            for i = 1:n
                idx = i - 1;  % zero-based
                if idx < obj.kStartMidIndex
                    freq = idx * obj.kHiXScale;
                    val  = rawSpec(i) * obj.kHiYScale;
                elseif idx < obj.kStartLowIndex
                    freq = (idx - obj.kStartMidIndex) * obj.kMidXScale;
                    val  = rawSpec(i) * obj.kMidYScale;
                else
                    freq = (idx - obj.kStartLowIndex) * obj.kLowXScale;
                    val  = rawSpec(i) * obj.kLowYScale;
                end
                psdTrace(i,1) = freq;
                psdTrace(i,2) = val;

                %RIN = PSD / ( (rmsVal * kHFSR)^2 )
                rinVal = val / ((rmsVal * obj.kHFSR)^2);
                rinTrace(i,1) = freq;
                rinTrace(i,2) = rinVal;
            end
        end

        function combined = CombineSpectra(obj, trace)
            % CombineSpectra  merges the low SR data first, mid SR second, high SR last
            if isempty(trace)
                combined = [];
                return;
            end
            combined = [];

            % Low part
            for i = (obj.kStartLowIndex+1) : size(trace,1)
                combined = [combined; trace(i,:)]; %#ok<AGROW>
            end
            lastFreq = combined(end,1);

            % Mid part
            for i = (obj.kStartMidIndex+1) : obj.kStartLowIndex
                if trace(i,1) > lastFreq
                    combined = [combined; trace(i,:)]; %#ok<AGROW>
                end
            end
            lastFreq = combined(end,1);

            % High part
            for i = 1 : obj.kStartMidIndex
                if trace(i,1) > lastFreq
                    combined = [combined; trace(i,:)]; %#ok<AGROW>
                end
                if trace(i,1) >= obj.kMaxFrequency
                    break;
                end
            end
        end

        function traceDB = ComputeDB(~, combined)
            % ComputeDB => 10 * log10(value), clamp to -140 if value<=0
            traceDB = zeros(size(combined));
            traceDB(:,1) = combined(:,1);
            for i = 1:size(combined,1)
                val = combined(i,2);
                if val <= 0
                    traceDB(i,2) = -140.0;
                else
                    traceDB(i,2) = 10 * log10(val);
                end
            end
        end

        function integrated = IntegrateData(~, combined, pct)
            % IntegrateData => sqrt of area under PSD or RIN
            % If pct==true, returns 0..100% scale
            if nargin<3, pct=false; end
            if isempty(combined)
                integrated = zeros(0,2);
                return;
            end

            integrated = zeros(size(combined));
            integrated(1,:) = [0,0];
            acc = 0.0;
            for i = 2:size(combined,1)
                dx = combined(i,1) - combined(i-1,1);
                yAvg = 0.5*(combined(i,2) + combined(i-1,2));
                acc = acc + yAvg*dx;

                if ~pct
                    integrated(i,1) = combined(i,1);
                    integrated(i,2) = sqrt(acc);
                else
                    val = 100.0 * sqrt(acc);
                    if val>100.0, val=100.0; end
                    integrated(i,:) = [combined(i,1), val];
                end
            end
        end

        function outTrace = SubtractReference(obj, refTrace, measuredTrace)
            % SubtractReference => measuredTrace - refTrace (clamp to kMinDiff)
            if size(refTrace,1)~=size(measuredTrace,1)
                error("PNA1:SubtractReference","Reference & measured sizes differ.");
            end
            outTrace = zeros(size(measuredTrace));
            for i = 1:size(measuredTrace,1)
                diffVal = measuredTrace(i,2) - refTrace(i,2);
                if diffVal < obj.kMinDiff
                    diffVal = obj.kMinDiff;
                end
                outTrace(i,:) = [measuredTrace(i,1), diffVal];
            end
        end

        %% --------------------- Logging Helpers ---------------------
        function Log(obj, msg)
            if obj.logging && obj.logFID>=0
                fprintf(obj.logFID,"[%s] %s\n", datestr(now), msg);
            end
        end

        function CloseLog(obj)
            if obj.logFID>=0
                fclose(obj.logFID);
                obj.logFID = -1;
            end
            obj.logging = false;
        end
    end

    %% --------------------- Private log method ---------------------
    methods (Access=private)
        function log(obj, msg)
            if obj.logging && obj.logFID>=0
                fprintf(obj.logFID, "[%s] %s\n", datestr(now), msg);
            end
        end
    end
end
