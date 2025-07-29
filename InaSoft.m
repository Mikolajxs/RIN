function results = InaSoft(ina_device, acq_time)
% Collect data from Intensity Noise Analyzer
% ina_device: Initialized PNA1 object
% acq_time: Acquisition duration in seconds

results = struct(...
    'timestamps', [], ...
    'rinDB', {{}} ...
);

startTime = tic;
sample_count = 0;

while toc(startTime) < acq_time
    try
        % Collect single trace (average of 1)
        [~, ~, ~, ~, ~, ~, ~, rinDB] = ina_device.AverageNoiseTraces(1);
        
        % Store results
        sample_count = sample_count + 1;
        results.timestamps(sample_count) = toc(startTime);
        results.rinDB{sample_count} = rinDB;
        
    catch ME
        fprintf('INA acquisition error: %s\n', ME.message);
    end
    pause(0.02);  
end
end