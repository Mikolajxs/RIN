% add the controller Matlab library to the path
arch = computer('arch');
if(strcmp(arch, 'win32'))
    addpath('..\..\Matlab\x86')
elseif(strcmp(arch, 'win64'))
    addpath('..\..\Matlab\x64')
end

disp('Connecting to the Soloist.')
handle = SoloistConnect;

disp('Enabling and homing the axis.')
SoloistMotionEnable(handle)
SoloistMotionHome(handle)


disp('Moving backward.')
SoloistMotionMoveInc(handle, 100, 2) % Distance - mm, speed mm/s, min - -750 mm, max = 750 mm
SoloistMotionWaitForMotionDone(handle, SoloistWaitOption.MoveDone, -1);
%disp('Moving forward.')
%SoloistMotionMoveAbs(handle, -200, 8) % Distance - mm. A speed 10 s - 100 mm, min - -750 mm, max = 750 mm
%SoloistMotionWaitForMotionDone(handle, SoloistWaitOption.InPosition, -1);

disp('Retrieving position feedback for the axis.')
posFeedback = SoloistStatusGetItem(handle, SoloistStatusItem.PositionFeedback);
fprintf('Position Feedback: %f\n', posFeedback)

% disp('Setting up some global variables.')
% SoloistVariableSetGlobalDouble(handle, 0, 100)
% SoloistVariableSetGlobalDouble(handle, 1, 20)
% 
% disp('Running programs.')
% SoloistProgramRun(handle, 1, '..\AeroBasic\ProgramFlow.ab')
% 
% disp('Stopping programs.')
% SoloistProgramStop(handle, 1)

disp('Disabling the axis.')
SoloistMotionDisable(handle)

disp('Disconnecting from the Soloist.')
SoloistDisconnect() % at the end of the program, always disconnect to prevent resource leaks
