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
total_distance = 600;
step_size = 100;
move_speed = 20;
acq_time = 3;

% Calculate number of steps
num_steps = total_distance / step_size;
if mod(num_steps, 1) ~= 0
    error('Total distance must be divisible by step size');
end
num_steps = round(num_steps);

%% Oscilloscope configuration 
% fprintf('\n--- Instrument Parameters ---\n');
% SCOPE_IP = '10.112.161.137';
% SCOPE_CH_SIG = 1;
% SCOPE_CH_REF = 2;
% resampling_factor = 2;
% scope_session = visa('ni',['TCPIP0::',SCOPE_IP,'::INSTR']);
% fopen(scope_session);
% fprintf('Configuring oscilloscope...\n');
% %fprintf(scope_session, '*RST');  % Reset to default state
% %pause(1);
    
%  Set trigger mode to SINGLE initially (will be controlled per step)
% fprintf(scope_session, 'TRMD AUTO');
% 
%  Set up basic acquisition parameters
% fprintf(scope_session, 'TDIV 200MS');  % Set timebase as needed
% fprintf(scope_session, 'C1:VDIV 200MV');  % Set voltage scale as needed
% fprintf(scope_session, 'C2:VDIV 1V');  % Set voltage scale as needed
% 
%  Set trigger source and level
% fprintf(scope_session, 'TRSE EDGE,SR,C1,HT,OFF');  % Edge trigger off

% END OF OSCILLOSCPE CONFIGURATION

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
    'ina_results', [], ...
    'scope_data', [] ...
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
        pause(0.5);  % Settling time
        
        % --- Store position data ---
        scan_data(step).step_number = step;
        scan_data(step).target_position = target_pos;
        scan_data(step).actual_position = actual_pos;

        % fprintf(scope_session, 'TRMD STOP');
        % pause(0.1);  % Small delay to ensure command is processed

        % % Wait for any ongoing acquisition to complete
        fprintf(scope_session, 'WAIT');
        % fprintf('Oscilloscope acquisition stopped for measurements...\n');
        
        % --- Collect INA data ---
        fprintf('Collecting INA data (%.1f seconds)...\n', acq_time);
        scan_data(step).ina_results = InaSoft(ina_device, acq_time);
        
        % --- Collect scope data ---
        %scan_data(step).scope_data = ScopeSoft(SCOPE_IP, SCOPE_CH_SIG, SCOPE_CH_REF, resampling_factor);
        fprintf('Collecting oscilloscope data (%.1f seconds)...\n', acq_time);
        % scan_data(step).scope_data = ScopeSoft(SCOPE_IP, SCOPE_CH_SIG, SCOPE_CH_REF, resampling_factor);
        
        % --- Save intermediate results ---
        save(fullfile(save_dir, sprintf('step_%d_data.mat', step)), 'scan_data');
        fprintf('Data saved for step %d\n', step);
        % --- RESTART OSCILLOSCOPE ACQUISITION ---
        % Set trigger mode back to AUTO or NORMAL for continuous acquisition
        % fprintf(scope_session, 'TRMD AUTO');  % or 'TRMD NORM' for normal triggering
        % fprintf('Oscilloscope acquisition restarted.\n');
        
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

%%CLEANUP AFTER OSCILLOSCOPE
% fclose(scope_session);
% delete(scope_session);
% clear scope_session

% Save final dataset
save(fullfile(save_dir, 'full_scan_data.mat'), 'scan_data', ...
    'total_distance', 'step_size', 'move_speed', 'acq_time');
fprintf('\nScan complete! All data saved to:\n%s\n', save_dir);