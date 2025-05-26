%% measurement_and_move_script.m
% Hard‑coded step‑measurement script for Soloist + Noise Analyzer
% basePos is read from Soloist after homing.
% Edit the User Settings below before running.

%User Settings
mode         = 1;                % 1=full ±maxDist, 2=forward only, 3=backward only
maxDist      = 500;              % max travel from basePos in mm (0<maxDist≤750)
step_um      = 0.5;              % step size in µm (≥0.1)
saveFilename = 'measurement_data.mat';  % output .mat filename

%Validate Inputs (no prompts)
assert(ismember(mode,1:3), 'mode must be 1,2 or 3');
assert(maxDist>0 && maxDist<=750, 'maxDist must be in (0,750]');
assert(step_um>=0.1, 'step_um must be ≥0.1 µm');
assert(ischar(saveFilename) && endsWith(saveFilename, '.mat'), 'Filename must end in .mat');

%Compute Relative Offsets
step_mm = step_um * 1e-3;
switch mode
    case 1; relStart = -maxDist; relEnd =  maxDist;
    case 2; relStart = 0;       relEnd =  maxDist;
    case 3; relStart = 0;       relEnd = -maxDist;
end
if relStart < relEnd
    relVec = relStart:step_mm:relEnd;
else
    relVec = relStart:-step_mm:relEnd;
end
Nsteps = numel(relVec);

%Preallocate Results 
results.rinDB = cell(1, Nsteps);

%Connect to Soloist 
arch = computer('arch');
if strcmp(arch,'win32')
    addpath('..\\..\\Matlab\\x86');
else
    addpath('..\\..\\Matlab\\x64');
end
handle = SoloistConnect();
SoloistMotionEnable(handle);
SoloistMotionHome(handle);
SoloistMotionWaitForMotionDone(handle, SoloistWaitOption.InPosition, -1);

% Read base position from device after homing
basePos = SoloistStatusGetItem(handle, SoloistStatusItem.PositionFeedback);
fprintf('Base position (home) = %.3f mm\n', basePos);

% Build Absolute Position Vector 
posVec = basePos + relVec;

%Connect to Noise Analyzer 
pna = PNA1('', 'TL_NA_SDK.dll');
pna.Initialize();
fprintf('Connected to Noise Analyzer S/N %s\n', pna.GetSerialNumber());

%Step‑Measurement Loop
tic;
for k = 1:Nsteps
    target = posVec(k);
    SoloistMotionMoveAbs(handle, target, 2);
    SoloistMotionWaitForMotionDone(handle, SoloistWaitOption.MoveDone, -1);

    [~,~,~,~,~,~,~, rinDB,~,~] = pna.AverageNoiseTraces(1);
    results.rinDB{k} = rinDB;
end

%Cleanup
pna.Close();
SoloistMotionDisable(handle);
SoloistDisconnect(handle);

%Save Data 
save(saveFilename, 'results');
fprintf('Completed %d measurements; data saved to %s\n', Nsteps, saveFilename);
