%% Single Oscilloscope Data Collection
% This script collects one measurement from the oscilloscope
% Uses acquireSds2354X function to get data from both channels
% Used for the step scan measurements usin RGH22S50F61A
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; close all; clc;

%% Configuration Parameters
SCOPE_IP = '10.112.161.137';
SCOPE_CHANNEL_SIG = 1;  
SCOPE_CHANNEL_REF = 2;  % Reference signal
resamplingFactor = 2;

%% Data Collection
fprintf('=== Single Oscilloscope Measurement ===\n');
fprintf('Connecting to oscilloscope at %s...\n', SCOPE_IP);

try
    % Connect to the oscilloscope
    scope_session = visa('ni',['TCPIP0::',SCOPE_IP,'::INSTR']);
    fopen(scope_session);
    
    % Stop the oscilloscope's acquisition
    fprintf(scope_session, 'STOP');
    fprintf('Oscilloscope stopped for data capture.\n');
    
    % Brief pause for stabilization
    pause(0.5);
    
    % Collect data from both channels
    fprintf('Collecting data from channel %d (signal)...\n', SCOPE_CHANNEL_SIG);
    ch1_data = acquireSds2354X(SCOPE_IP, SCOPE_CHANNEL_SIG, resamplingFactor);
    
    fprintf('Collecting data from channel %d (reference)...\n', SCOPE_CHANNEL_REF);
    ch2_data = acquireSds2354X(SCOPE_IP, SCOPE_CHANNEL_REF, resamplingFactor);
    
    % Restart the oscilloscope
    fprintf(scope_session, 'RUN');
    fprintf('Oscilloscope restarted.\n');
    
    % Close the VISA session
    fclose(scope_session);
    delete(scope_session);
    clear scope_session;
    
    fprintf('Data collection completed successfully.\n');
    
catch ex
    fprintf('Error during data collection: %s\n', ex.message);
    
    % Ensure VISA session is closed even if error occurs
    if exist('scope_session', 'var')
        try
            fclose(scope_session);
            delete(scope_session);
        catch
            % Ignore cleanup errors
        end
    end
    return;
end

%% Display Results
if exist('ch1_data', 'var') && exist('ch2_data', 'var')
    fprintf('\n=== Measurement Results ===\n');
    
    % Channel 1 info
    if ~isempty(ch1_data) && isfield(ch1_data, 'y')
        fprintf('Channel 1 (Signal):\n');
        fprintf('  Samples: %d\n', length(ch1_data.y));
        fprintf('  Mean voltage: %.6f V\n', mean(ch1_data.y));
        fprintf('  Std deviation: %.6f V\n', std(ch1_data.y));
        fprintf('  Min voltage: %.6f V\n', min(ch1_data.y));
        fprintf('  Max voltage: %.6f V\n', max(ch1_data.y));
    else
        fprintf('Channel 1: No valid data acquired\n');
    end
    
    % Channel 2 info
    if ~isempty(ch2_data) && isfield(ch2_data, 'y')
        fprintf('Channel 2 (Reference):\n');
        fprintf('  Samples: %d\n', length(ch2_data.y));
        fprintf('  Mean voltage: %.6f V\n', mean(ch2_data.y));
        fprintf('  Std deviation: %.6f V\n', std(ch2_data.y));
        fprintf('  Min voltage: %.6f V\n', min(ch2_data.y));
        fprintf('  Max voltage: %.6f V\n', max(ch2_data.y));
    else
        fprintf('Channel 2: No valid data acquired\n');
    end
end

%% Plot the Data (Optional - for debugging)
% if exist('ch1_data', 'var') && exist('ch2_data', 'var') && ...
%    ~isempty(ch1_data) && ~isempty(ch2_data) && ...
%    isfield(ch1_data, 'y') && isfield(ch2_data, 'y')
% 
%     figure('Name', 'Oscilloscope Single Measurement', 'Position', [100, 100, 1200, 600]);
% 
%     subplot(2,1,1);
%     plot(ch1_data.x, ch1_data.y * 1000, 'b-', 'LineWidth', 1);
%     title('Signal Channel (CH1)');
%     xlabel('Time (s)');
%     ylabel('Voltage (mV)');
%     grid on;
% 
%     subplot(2,1,2);
%     plot(ch2_data.x, ch2_data.y, 'r-', 'LineWidth', 1);
%     title('Reference Channel (CH2)');
%     xlabel('Time (s)');
%     ylabel('Voltage (V)');
%     grid on;
% 
%     fprintf('\nData plotted successfully.\n');
% else
%     fprintf('\nWarning: Could not plot data - invalid or empty datasets.\n');
% end

%% Save Data (Optional - for debugging)
% save_data = input('\nSave data to .mat file? (y/n): ', 's');
% if strcmpi(save_data, 'y')
%     timestamp = datestr(now, 'yyyymmdd_HHMMSS');
%     filename = sprintf('oscilloscope_measurement_%s.mat', timestamp);
% 
%     % Create data structure
%     measurement_data = struct();
%     measurement_data.ch1 = ch1_data;
%     measurement_data.ch2 = ch2_data;
%     measurement_data.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
%     measurement_data.scope_ip = SCOPE_IP;
%     measurement_data.resampling_factor = resamplingFactor;
% 
%     save(filename, 'measurement_data', '-v7.3');
%     fprintf('Data saved to: %s\n', filename);
% end

fprintf('\nMeasurement complete.\n');