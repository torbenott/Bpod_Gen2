function AnalogOutputWavePlayer()
%{
A stimulus sandbox which cycles through candidate waveforms.
Serves as a simple example of using the BpodWavePlayer to produce sounds.
%}

global BpodSystem

%{
---------------------------------------------------------------------------
                                SETUP
---------------------------------------------------------------------------
You will need:
- A Bpod state machine v0.7+
- A Bpod analog output module, loaded with Bpod BpodWavePlayer firmware.

- Connect the analog output module's State Machine port to Bpod.
- Connect channel 1 (or ch1+2) of the analog output module to speaker(s).
- Plug in the analog otuput module to the computer via USB and start Bpod
  in Matlab.  From the Bpod console, pfsair the serial port (left) module 
  with its USB serial port (right).
%}

%--------------------------------------------------------------------------
% Instantiate waveplayer and set parameters
%--------------------------------------------------------------------------
% Check that the Analog Output Module hardware has been assigned a USB port
if (isfield(BpodSystem.ModuleUSB, 'WavePlayer1'))
    WavePlayerUSB = BpodSystem.ModuleUSB.WavePlayer1;
else
    error('Error: To run this protocol, you must first pair the Analog Output Module (hardware) with its USB port. Click the USB config button on the Bpod console.')
end
% Instantiate BpodWavePlayer object
Player = BpodWavePlayer(WavePlayerUSB);
Player.Port

fs = 10000 % Use max (10kHz) supported sampling rate (fs = sampling freq)
Player.SamplingRate = fs;
Player.BpodEvents = {'On', 'On', 'Off', 'Off', 'Off', 'Off', 'Off', 'Off'}; % for 8-channel hardware
Player.TriggerMode = 'Master';
Player.OutputRange = '-5V:5V';
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
% Define stimuli and send to analog module
%--------------------------------------------------------------------------
SoundDuration = 0.5; % Duration of sound (s)
SinWaveFreqLeft = 500; % Frequency of left cue
SinWaveFreqRight = 2000; % Frequency of right cue

% Sampling freq (hz), Sine frequency (hz), duration (s)
LeftSound = GenerateSineWave(fs, SinWaveFreqLeft, SoundDuration)*.9; 
% Sampling freq (hz), Sine frequency (hz), duration (s)
RightSound = GenerateSineWave(fs, SinWaveFreqRight, SoundDuration)*.9; 
PunishSound = rand(1, fs*.5)*2 - 1;

% Generate early withdrawal sound
W1 = GenerateSineWave(fs, 1000, .5); 
W2 = GenerateSineWave(fs, 1200, .5); 
EarlyWithdrawalSound = W1+W2;
P = fs/100; 
Interval = P;
for x = 1:50 % Gate waveform to create pulses
    EarlyWithdrawalSound(P:P+Interval) = 0;
    P = P+(Interval*2);
end

Player.loadWaveform(1, LeftSound);
Player.loadWaveform(2, RightSound);
Player.loadWaveform(3, PunishSound);
Player.loadWaveform(4, EarlyWithdrawalSound);
Envelope = 0.005:0.005:1; % Define envelope of amplitude coefficients, 
                          % to play at sound onset + offset
% Player.Waveforms;  % Can be uncommented to check that the waveforms were
                     % properly loaded
%--------------------------------------------------------------------------


%{
---------------------------------------------------------------------------
                 Set up Bpod serial message library 
---------------------------------------------------------------------------
 (see
 https://sites.google.com/site/bpoddocumentation/user-guide/
                           function-reference/waveplayerserialinterface)
 sets correct codes to trigger sounds 1-4 on analog output channels 1-2

'P' (ASCII 80): Plays a waveform. 

    In standard trigger mode (default), 'P' (byte 0) must be followed by two bytes:
        Byte 1: A byte whose bits indicate which channels to trigger (i.e. byte 5 = bits: 101 = channels 1 and 3). 
        Byte 2: A byte indicating the waveform to play on the channels specified by Byte 1 (zero-indexed).

    In trigger profile mode, 'P' (byte 0) must be followed by 1 byte:
        Byte 1: The trigger profile to play (1-64)
%}
analogPortIndex = find(strcmp(BpodSystem.Modules.Name, 'WavePlayer1'));
if isempty(analogPortIndex)
    error('Error: Bpod WavePlayer module not found. If you just plugged it in, please restart Bpod.')
end
LoadSerialMessages('WavePlayer1', {['P' 3 0], ['P' 3 1], ['P' 3 2], ['P' 3 3]});  % 3=0011=channels 1&2, 0=first waveform


%--------------------------------------------------------------------------
% Main trial loop
%--------------------------------------------------------------------------
n_loops = 12;
state_duration = 1; % seconds
for currentTrial = 1:n_loops
    sma = NewStateMachine(); % Initialize new state machine description
    
    % initial state to flush waves
    sma = AddState(sma, 'Name', 'init_state', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'LeftSound'},...
        'OutputActions', {'WavePlayer1','*'}); % Code to push newly uploaded waves to front (playback) buffers
    
    % states to loop through
    sma = AddState(sma, 'Name', 'LeftSound', ...
        'Timer', state_duration,...
        'StateChangeConditions', {'Tup', 'RightSound'},...
        'OutputActions', {'WavePlayer1', 1});

    sma = AddState(sma, 'Name', 'RightSound', ...
        'Timer', state_duration,...
        'StateChangeConditions', {'Tup', 'Punish'},...
        'OutputActions', {'WavePlayer1', 2});

    sma = AddState(sma, 'Name', 'Punish', ...
        'Timer', state_duration,...
        'StateChangeConditions', {'Tup', 'EarlyWithdrawal'},...
        'OutputActions', {'WavePlayer1', 3});

    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', state_duration,...
        'StateChangeConditions', {'Tup', 'LeftSound'},...
        'OutputActions', {'WavePlayer1', 4});

    SendStateMatrix(sma); % Send the state matrix to the Bpod device
    RawEvents = RunStateMatrix; % Run the trial and return events

    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0 % If protocol was stopped, exit the loop
        return
    end
end