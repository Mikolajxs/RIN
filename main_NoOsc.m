%% main.m - Step-Scan Control System (Updated)
% Coordinates stage movement, INA data acquisition, and oscilloscope measurements

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
total_distance = 50;
step_size = 5;
move_speed = 10;
acq_time = 1;

% Calculate number of steps
num_steps = total_distance / step_size;
if mod(num_steps, 1) ~= 0
    error('Total distance must be divisible by step size');
end
num_steps = round(num_steps);

%% Initialize Hardware
try
    % Initialize motion controller
    fprintf('Initializing Soloist stage...\n');
    stage_handle = SoloistConnect();
    SoloistMotionEnable(stage_handle);
    SoloistMotionHome(stage_handle);
    
    % Initialize INA
    fprintf('Initializing Intensity Noise Analyzer...\n');
    ina_device = PNA1("", "TL_NA_SDK.dll"); 
    ina_device.Initialize();
    
    %Initialize NI cRIO 9215
    d = daq("ni");
    %devices = daqlist("ni");
    d.Rate = 8000;
    addinput(d, daqlist("ni").DeviceID(1), "ai0", "Voltage");
    %% Test read
    %data = read(d, seconds(1));
    %plot(data.Time, data.Variables);
    %ylabel("Voltage (V)")
    
    fprintf('All instruments initialized successfully!\n');
catch ME
    error('Hardware initialization failed: %s', ME.message);
end

%% Create Data Directory
data_dir = 'C:\Data\test\Mikolaj_test\2_09_25';
save_dir = fullfile(data_dir, ['StepScan_' datestr(now, 'yyyymmdd_HHMMSS')]);
mkdir(save_dir);
fprintf('\nData will be saved to: %s\n', save_dir);

%% Initialize Data Structures
scan_data = struct(...
    'step_number', [], ...
    'target_position', [], ...
    'actual_position', [], ...
    'ina_results', [],...
    'ni_voltage', []...
);

%% Main Step-Scan Loop
try
    for step = 1:num_steps
        fprintf('\n=== Step %d/%d ===\n', step, num_steps);
        
        % --- Calculate target position ---
        target_pos = (step-1) * step_size;
        
        % --- Move stage ---
        fprintf('Moving to %.2f mm at %.1f mm/s...\n', target_pos, move_speed);
        SoloistMotionMoveAbs(stage_handle, target_pos, move_speed);
        SoloistMotionWaitForMotionDone(stage_handle, SoloistWaitOption.MoveDone, -1);
        
        % --- Verify position ---
        actual_pos = SoloistStatusGetItem(stage_handle, SoloistStatusItem.PositionFeedback);
        fprintf('Arrived at: %.4f mm\n', actual_pos);
        pause(0.3);  % Settling time
        
        % --- Store position data ---
        scan_data(step).step_number = step;
        scan_data(step).target_position = target_pos;
        scan_data(step).actual_position = actual_pos;
     
        % --- Collect INA data ---
        fprintf('Collecting INA data (%.1f seconds)...\n', acq_time);
        scan_data(step).ina_results = InaSoft(ina_device, acq_time);

        % --- Collect NI cRIO 9215 DATA --
        flush(d); %flushing data before making next read
        ni_data = read(d); % One-shot read
        scan_data(step).ni_voltage = ni_data.Variables; % Store just the voltage value

        % --- Save intermediate results ---
        save(fullfile(save_dir, sprintf('step_%d_data.mat', step)), 'scan_data');
        fprintf('Data saved for step %d\n', step);
        
        
        pause(0.2);  % Small delay before next step
    end
    
    % --- Return to home position ---
    fprintf('\nReturning to home position...\n');
    SoloistMotionMoveAbs(stage_handle, 0, 100);
    SoloistMotionWaitForMotionDone(stage_handle, SoloistWaitOption.MoveDone, -1);
    
catch ME
    fprintf('Error during step %d: %s\n', step, ME.message);
end

%% Cleanup and Final Save
% Release hardware resources
SoloistMotionDisable(stage_handle);
SoloistDisconnect();
ina_device.Close();
clear d;

% Save final dataset
save(fullfile(save_dir, 'full_scan_data.mat'), 'scan_data', ...
    'total_distance', 'step_size', 'move_speed', 'acq_time');
fprintf('\nScan complete! All data saved to:\n%s\n', save_dir);