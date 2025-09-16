%% main.m - Step-Scan Control System with Multiple Movement Modes
% Coordinates stage movement, INA data acquisition, and NI cRIO 9215 measurements

%% Initialize System
clear; clc; close all;
fprintf('=== Step-Scan Measurement System ===\n');

% Add Soloist controller library to path
arch = computer('arch');
if strcmp(arch, 'win32')
    addpath('Matlab\x86');
elseif strcmp(arch, 'win64')
    addpath('Matlab\x64');
end

%% User Configuration
fprintf('\n--- Step Parameters ---\n');

RefWavelength = 1532.83045; % nm

% Movement mode selection
% Select movement mode
% 1: Full range (-maxDist to +maxDist)
% 2: Forward only (0 to +maxDist)
% 3: Backward only (0 to -maxDist)
mode = 1;
% Distance parameters
maxDist = 0.00625/4; %mm
step_size = RefWavelength/16 * 1e-6; % mm
move_speed = 5; 

acq_time = 1.0;
settling_time = 0.2;

%% Initialize Hardware
try
    % Initialize motion controller
    fprintf('Initializing Soloist stage...\n');
    stage_handle = SoloistConnect();
    SoloistMotionEnable(stage_handle);
    SoloistMotionHome(stage_handle);
    
    % Read base position from device after homing
    basePos = SoloistStatusGetItem(stage_handle, SoloistStatusItem.PositionFeedback);
    fprintf('Base position (home) = %.3f mm\n', basePos);
    
    % Initialize INA
    fprintf('Initializing Intensity Noise Analyzer...\n');
    ina_device = PNA1("", "TL_NA_SDK.dll"); 
    ina_device.Initialize();
    
    % Initialize NI cRIO 9215 with both AI0 and AI1 channels
    fprintf('Initializing NI USB 6002...\n');
    ni_devices = daqlist("ni");
    if isempty(ni_devices)
        error('No NI devices found. Please check your connections.');
    end
    
    d = daq("ni");
    d.Rate = 5000;
    
    % Add analog input channels with RSE (Referenced Single-Ended) configuration
    % RSE is appropriate for single-ended measurements referenced to ground
    ch1 = addinput(d, ni_devices.DeviceID(1), "ai0", "Voltage");
    ch2 = addinput(d, ni_devices.DeviceID(1), "ai1", "Voltage");
    
    % Set terminal configuration to RSE (Referenced Single-Ended)
    ch1.TerminalConfig = "SingleEnded"; %''Differential', 'SingleEnded', 'SingleEndedNonReferenced', 'PseudoDifferential'    %ch2.TerminalConfig = "SingleEnded";
    fprintf('All instruments initialized successfully!\n');
catch ME
    error('Hardware initialization failed: %s', ME.message);
end

%% Calculate Position Vector Based on Mode
switch mode
    case 1 % Full range (-maxDist to +maxDist)
        relStart = -maxDist;
        relEnd = maxDist;
    case 2 % Forward only (0 to +maxDist)
        relStart = 0;
        relEnd = maxDist;
    case 3 % Backward only (0 to -maxDist)
        relStart = 0;
        relEnd = -maxDist;
end

% Generate position vector
if relStart < relEnd
    relVec = relStart:step_size:relEnd;
else
    relVec = relStart:-step_size:relEnd;
end

% Convert to absolute positions
posVec = basePos + relVec;
num_steps = length(posVec);

fprintf('Number of steps: %d\n', num_steps);
fprintf('Position range: %.2f to %.2f mm\n', min(posVec), max(posVec));

%% Create Data Directory
data_dir = 'C:\Data\test\Mikolaj_test\16_09_25';
save_dir = fullfile(data_dir, ['StepScan_' datestr(now, 'yyyymmdd_HHMMSS')]);
mkdir(save_dir);
fprintf('\nData will be saved to: %s\n', save_dir);

%% Preparations for continous measurements

% Prepare a buffer inside the DataAcquisition to collect chunks
d.UserData = struct('t',[], 'y',[]);

% Process ~50 ms windows per callback (adjust if you like)
d.ScansAvailableFcnCount = 1000;
d.ScansAvailableFcn = @(src,evt) collectChunkToUserData(src);

% Start continuous background acquisition once (before your step loop)
start(d, "continuous");

%% Initialize Data Structures
scan_data = struct(...
    'step_number', [], ...
    'target_position', [], ...
    'actual_position', [], ...
    'timestamps', [], ...
    'ina_results', [],...
    'ni_results', []...
);

%% Main Step-Scan Loop
try
    for step = 1:num_steps
        fprintf('\n=== Step %d/%d ===\n', step, num_steps);
        
        % --- Calculate target position ---
        target_pos = posVec(step);
        
        % --- Move stage ---
        fprintf('Moving to %.2f mm at %.1f mm/s...\n', target_pos, move_speed);
        SoloistMotionMoveAbs(stage_handle, target_pos, move_speed);
        SoloistMotionWaitForMotionDone(stage_handle, SoloistWaitOption.MoveDone, -1);
        
        % --- Verify position ---
        actual_pos = SoloistStatusGetItem(stage_handle, SoloistStatusItem.PositionFeedback);
        fprintf('Arrived at: %.4f mm (target: %.4f mm)\n', actual_pos, target_pos);
        pause(settling_time);  % Settling time
        
        % --- Store position data ---
        scan_data(step).step_number = step;
        scan_data(step).target_position = target_pos;
        scan_data(step).actual_position = actual_pos;
     
        % --- Collect INA data ---
        fprintf('Collecting INA data (%.1f seconds)...\n', acq_time);
        scan_data(step).ina_results = InaSoft(ina_device, acq_time); 
        
        % Reset step buffer
        d.UserData.t = [];
        d.UserData.y = [];

        % Let it accumulate for the window you want
        pause(acq_time);

        % Snapshot the accumulated window (t is seconds since DAQ start)
        t_step = d.UserData.t;
        y_step = d.UserData.y;

        % Store into scan_data
        fprintf('Collecting NI data');
        scan_data(step).timestamps = t_step;   
        scan_data(step).ni_results  = y_step;  
        

        % --- Save intermediate results ---
        save(fullfile(save_dir, sprintf('step_%d_data.mat', step)), 'scan_data');
        fprintf('Data saved for step %d\n', step);
        
        pause(0.1);  % Small delay before next step
    end
    
    % --- Return to home position ---
    fprintf('\nReturning to home position...\n');
    SoloistMotionMoveAbs(stage_handle, basePos, 100);
    SoloistMotionWaitForMotionDone(stage_handle, SoloistWaitOption.MoveDone, -1);
    
catch ME
    fprintf('Error during step %d: %s\n', step, ME.message);
end

%% Cleanup and Final Save
% Release hardware resources
SoloistMotionDisable(stage_handle);
SoloistDisconnect();
ina_device.Close();
stop(d);
clear d;

% Save final dataset with all parameters included
save(fullfile(save_dir, 'full_scan_data.mat'), 'scan_data', ...
    'mode', 'maxDist', 'step_size', 'move_speed', 'acq_time', 'basePos', 'posVec');
fprintf('\nScan complete! All data saved to:\n%s\n', save_dir);


function collectChunkToUserData(src)
    % Read exactly ScansAvailableFcnCount scans as a timetable
    tt = read(src, src.ScansAvailableFcnCount, "OutputFormat", "timetable");
    % Append time (seconds since acquisition started) and data (matrix)
    src.UserData.t = [src.UserData.t; seconds(tt.Time)];
    src.UserData.y = [src.UserData.y; tt.Variables];
end
