function scope_data = ScopeSoft(ip, ch_sig, ch_ref, resamplingFactor,acq_time)
% Collect data from oscilloscope using modern VISA interface
startTime = tic;
while toc(startTime) < acq_time
    try
    
    % Collect data from both channels
    scope_data.ch1 = acquireSds2354X(ip, ch_sig, resamplingFactor);
    scope_data.ch2 = acquireSds2354X(ip, ch_ref, resamplingFactor);
    
    % Cleanup connection
    clear scope;
    
catch ME
    fprintf('Oscilloscope error: %s\n', ME.message);
    scope_data = struct('ch1', [], 'ch2', []);
    
    % Ensure resource cleanup
    if exist('scope', 'var')
        try
            clear scope;
        catch
            % Ignore cleanup errors
        end
    end
    end
end
end
