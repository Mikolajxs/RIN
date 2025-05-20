disp('Adding the controller Matlab library to the path.')
arch = computer('arch');
if(strcmp(arch, 'win32'))
	addpath('..\..\Matlab\x86')
elseif(strcmp(arch, 'win64'))
	addpath('..\..\Matlab\x64')
end

disp('Connecting to the Soloist.')
handles = SoloistConnect;

disp('Creating a data collection configuration.')
dataCollHandle = SoloistDataCollectionConfigCreate(handles(1));

disp('Configuring to collect position feedback and velocity feedback data on the axis.')
SoloistDataCollectionConfigAddSignal(dataCollHandle, SoloistDataSignal.PositionFeedback, 0, 0)
SoloistDataCollectionConfigAddSignal(dataCollHandle, SoloistDataSignal.VelocityFeedback, 0, 0)

disp('Configuring to collect one sample every one millisecond.')
SoloistDataCollectionConfigSetPeriod(dataCollHandle, 1)

disp('Configuring to collect 1000 samples.')
SoloistDataCollectionConfigSetSamples(dataCollHandle, 1000)

disp('Start collecting the data.')
SoloistDataCollectionStart(handles(1), dataCollHandle)

disp('Retrieving all 1000 data samples.')
collectedData = SoloistDataCollectionDataRetrieve(handles(1), dataCollHandle, 1000);

disp('Printing out the collected data.')
sampleNumber = 1;
while sampleNumber <= 1000
	disp(['Position Feedback : ', num2str(collectedData(1, sampleNumber))])
	disp(['Velocity Feedback : ', num2str(collectedData(2, sampleNumber))])
	sampleNumber = sampleNumber + 1;
end

disp('Freeing the resources used by the data collection configuration.')
SoloistDataCollectionConfigFree(dataCollHandle);

disp('Disconnecting from the Soloist.')
SoloistDisconnect;