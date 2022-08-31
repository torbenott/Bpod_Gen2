%{
This file is a modified version of the AnalogSound2AFC protocol provided
in the Sanworks Bpod repository

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

function AnalogOutputModule2AFC()
%{
---------------------------------------------------------------------------
    This protocol demonstrates a 2AFC task 
     using the 8-channel analog output module to generate sound stimuli.
---------------------------------------------------------------------------

    - Subjects initialize each trial with a poke into port 2. 
    - After a delay, a tone plays.
    - If subjects exit the port before the tone is finished playing, 
      a dissonant error sound is played.
    - Subjects are rewarded for responding:
        - left for low-pitch tones
        - right for high.
    - A white noise pulse indicates incorrect choice.

NOTE: We use BpodWavePlayer to play sound in this demo because the task's 
reinforcement cues could be any 4 sounds that are easily discriminated 
from each other. A proper sound card is necessary for studies where 
auditory signal quality is critical to analysis.
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
% Define parameters
%--------------------------------------------------------------------------
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.TrainingLevel = 2; % Configurable reward condition schemes. 'BothCorrect' rewards either side.
    S.GUIMeta.TrainingLevel.Style = 'popupmenu'; % the GUIMeta field is used by the ParameterGUI plugin to customize UI objects.
    S.GUIMeta.TrainingLevel.String = {'BothCorrect', '2AFC'};
    S.GUI.SoundDuration = 0.5; % Duration of sound (s)
    S.GUI.SinWaveFreqLeft = 500; % Frequency of left cue
    S.GUI.SinWaveFreqRight = 2000; % Frequency of right cue
    S.GUI.RewardAmount = 5; % in ul
    S.GUI.StimulusDelayDuration = 0; % Seconds before stimulus plays on each trial
    S.GUI.TimeForResponse = 5; % Seconds after stimulus sampling for a response
    S.GUI.PunishTimeoutDuration = 2; % Seconds to wait on errors before next trial can start
    S.GUI.PunishSound = 1; % if 1, plays a white noise pulse on error. if 0, no sound is played.
    S.GUIMeta.PunishSound.Style = 'checkbox';
    S.GUIPanels.Task = {'TrainingLevel', 'RewardAmount', 'PunishSound'}; % GUIPanels organize the parameters into groups.
    S.GUIPanels.Sound = {'SinWaveFreqLeft', 'SinWaveFreqRight', 'SoundDuration'};
    S.GUIPanels.Time = {'StimulusDelayDuration', 'TimeForResponse', 'PunishTimeoutDuration'};
end

% Define trials
MaxTrials = 5000;
TrialTypes = ceil(rand(1,MaxTrials)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
% Initialize plots
%--------------------------------------------------------------------------
% Side Outcome Plot
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [50 540 1000 220],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .35 .89 .55]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
BpodParameterGUI('init', S); % Initialize parameter GUI plugin
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
% Define stimuli and send to analog module
%--------------------------------------------------------------------------
% Sampling freq (hz), Sine frequency (hz), duration (s)
LeftSound = GenerateSineWave(fs, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration)*.9; 
% Sampling freq (hz), Sine frequency (hz), duration (s)
RightSound = GenerateSineWave(fs, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration)*.9; 
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


% Remember values of left and right frequencies & durations, so a new one only gets uploaded if it was changed
LastLeftFrequency = S.GUI.SinWaveFreqLeft; 
LastRightFrequency = S.GUI.SinWaveFreqRight;
LastSoundDuration = S.GUI.SoundDuration;

%--------------------------------------------------------------------------
% Main trial loop
%--------------------------------------------------------------------------
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    if S.GUI.PunishSound
        PunishOutputAction = {'WavePlayer1', 3};
    else
        PunishOutputAction = {};
    end

    if S.GUI.SinWaveFreqLeft ~= LastLeftFrequency
        LeftSound = GenerateSineWave(SF, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
        Player.loadWaveform(1, LeftSound);
        LastLeftFrequency = S.GUI.SinWaveFreqLeft;
    end

    if S.GUI.SinWaveFreqRight ~= LastRightFrequency
        RightSound = GenerateSineWave(SF, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
        Player.loadWaveform(2, RightSound);
        LastRightFrequency = S.GUI.SinWaveFreqRight;
    end

    if S.GUI.SoundDuration ~= LastSoundDuration
        LeftSound = GenerateSineWave(SF, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
        RightSound = GenerateSineWave(SF, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
        Player.loadWaveform(1, LeftSound); 
        Player.loadWaveform(2, RightSound);
        LastSoundDuration = S.GUI.SoundDuration;
    end

    R = GetValveTimes(S.GUI.RewardAmount, [1 3]); 
    LeftValveTime = R(1); 
    RightValveTime = R(2); % Update reward amounts

    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            OutputActionArgument = {'WavePlayer1', 1, 'BNCState', 2}; 
            LeftActionState = 'Reward';  
            RightActionState = 'Punish'; 
            CorrectWithdrawalEvent = 'Port1Out';
            ValveCode = 1; ValveTime = LeftValveTime;
        case 2
            OutputActionArgument = {'WavePlayer1', 2, 'BNCState', 2};
            LeftActionState = 'Punish'; 
            RightActionState = 'Reward'; 
            CorrectWithdrawalEvent = 'Port3Out';
            ValveCode = 4; 
            ValveTime = RightValveTime;
    end

    if S.GUI.TrainingLevel == 1 % Reward both sides (overriding switch/case above)
        RightActionState = 'Reward'; LeftActionState = 'Reward';
    end

    sma = NewStateMachine(); % Initialize new state machine description
    sma = SetCondition(sma, 1, 'Port1', 0); % Condition 1: Port 1 low (is out)
    sma = SetCondition(sma, 2, 'Port3', 0); % Condition 2: Port 3 low (is out)
    sma = AddState(sma, 'Name', 'WaitForCenterPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'Delay'},...
        'OutputActions', {'WavePlayer1','*'}); % Code to push newly uploaded waves to front (playback) buffers
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', S.GUI.StimulusDelayDuration,...
        'StateChangeConditions', {'Port2Out', 'EarlyWithdrawal', 'Tup', 'DeliverStimulus'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.SoundDuration,...
        'StateChangeConditions', {'Tup', 'WaitForResponse', 'Port2Out', 'EarlyWithdrawal'},...
        'OutputActions', OutputActionArgument);
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.TimeForResponse,...
        'StateChangeConditions', {'Tup', '>exit', 'Port1In', LeftActionState, 'Port3In', RightActionState},...
        'OutputActions', {'PWM1', 255, 'PWM3', 255});
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', ValveCode});
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', 0,...
        'StateChangeConditions', {'Condition1', 'DrinkingGrace', 'Condition2', 'DrinkingGrace'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'DrinkingGrace', ...
        'Timer', 0.5,...
        'StateChangeConditions', {'Tup', '>exit', 'Port1In', 'Drinking', 'Port3In', 'Drinking'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Punish', ...
        'Timer', S.GUI.PunishTimeoutDuration,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', PunishOutputAction);
    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', S.GUI.PunishTimeoutDuration,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {'WavePlayer1', 4});

    SendStateMatrix(sma); % Send the state matrix to the Bpod device

    RawEvents = RunStateMatrix; % Run the trial and return events
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned (i.e. if not final trial, interrupted by user)
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0 % If protocol was stopped, exit the loop
        return
    end
end % Main trial loop
%--------------------------------------------------------------------------





function UpdateSideOutcomePlot(TrialTypes, Data)
% Determine outcomes from state data and score as the SideOutcomePlot plugin expects
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
        Outcomes(x) = 0;
    else
        Outcomes(x) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);




function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
    TotalRewardDisplay('add', RewardAmount);
end
