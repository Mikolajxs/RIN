% sdk_example2.m

%% Initialize Device
try
    pna = PNA1("", "TL_NA_SDK.dll"); 
    
    % Initialize communication
    pna.Initialize();
    fprintf('Connected to device: %s\n', pna.GetSerialNumber());
    
catch ME
    fprintf('Initialization failed: %s\n', ME.message);
    return;
end

%% Data Collection Setup
% Create results structure with ALL fields
results = struct(...
    'timestamps', [], ...      % Collection timestamps (seconds)
    'rinDB',      {{}} ...     % RIN spectra (cell array of [freq, dBc/Hz] matrices)
);
    %example of the rest of data collection setup:
    %'psdDB',      {{}}, ...    % PSD spectra (cell array of [freq, dBV/√Hz] matrices)
    %'intRIN',     {{}}, ...    % Integrated RIN (cell array of [freq, %RMS] matrices)
    %'V_RMS',      [], ...      RMS voltage measurements (V)
    %'V_DC',       [] ...       DC voltage measurements (V)


startTime = tic;  % Start timer

%% Main Acquisition Loop
while toc(startTime) < 5  % Run for x seconds
    try
        % Get ALL noise parameters from device
        % AnalyzeNoise returns:
        % [rmsVal, dcVal, psdFull, rinFull, psdComb, rinComb, psdDB, rinDB, intPSD, intRIN]
        [~, ~, ~, ~, ~, ~, ~, rinDB, ~, ~] = pna.AnalyzeNoise();
        %[~, ~, ~, ~, ~, ~, ~, rinDB, ~, ~] = pna.AverageNoiseTraces(3);
        % Store parameters
        results.timestamps(end+1) = toc(startTime);          % Current time
        results.rinDB{end+1} = rinDB;                        % RIN spectrum
        %results.psdDB{end+1} = psdDB;                        % PSD spectrum
        %results.intRIN{end+1} = intRIN;                      % Integrated RIN
        %results.V_RMS(end+1) = rmsRaw * pna.kHFSR;           % Scaled RMS voltage
        %results.V_DC(end+1) = dcRaw * pna.kHFSR;             % Scaled DC voltage
        
    catch ME
        fprintf('Acquisition error: %s\n', ME.message);
    end
    
    pause(0.1);  % 3 measurements per second
end

%% Cleanup
pna.Close();
clear pna;
save('data.mat', 'results'); 
fprintf('Data collection complete. Saved %d samples to data.mat\n', numel(results.timestamps));