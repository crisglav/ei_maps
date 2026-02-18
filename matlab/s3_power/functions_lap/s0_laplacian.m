clc
clear
close all

% Sets the paths.
config.path.segs = '../../data/segments/';
config.path.slap = '../../data/segments_slap/';
config.path.patt = '*.mat';

% Sets the action when the task have already been processed.
config.overwrite = false;


% Adds the 'functions' folder to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );
addpath ( sprintf ( '%s/functions/', pwd ) );

% Adds, if needed, the FieldTrip folder to the path.
ft_path
ft_defaults

% Disables the FT feedback.
global ft_default;
ft_default.showcallinfo = 'no';
ft_default.checkconfig  = 'silent';


% Loads the "ideal" electrode definition.
sensmeta = load ( 'ane64' );


% Creates and output folder, if needed.
if ~exist ( config.path.slap, 'dir' ), mkdir ( config.path.slap ); end

% Gets the list of subjects.
files = dir ( sprintf ( '%s%s', config.path.segs, config.path.patt ) );

% Goes through each file.
for findex = 1: numel ( files )
    
    % Pre-loads the data.
    sensdata         = load ( sprintf ( '%s%s', config.path.segs, files ( findex ).name ), 'subject', 'task', 'channel' );
    
    if ~config.overwrite && exist ( sprintf ( '%s%s_%s_%s.mat', config.path.slap, sensdata.subject, sensdata.task, sensdata.channel ), 'file' )
        fprintf ( 1, 'Ignoring with subject %s, task %s, channel %s (already calcualted).\n', sensdata.subject, sensdata.task, sensdata.channel );
        continue
    end
    
    fprintf ( 1, 'Working with subject %s, task %s, channel %s.\n', sensdata.subject, sensdata.task, sensdata.channel );
    
    
    fprintf ( 1, '  Loading the data.\n' );
    
    % Loads the data.
    sensdata         = myft_load ( sprintf ( '%s%s', config.path.segs, files ( findex ).name ) );
    
    % Gets the data itself.
    trialdata        = sensdata.trialdata;
    
    
    fprintf ( 1, '  Calculating the surface Laplacian.\n' );
    
    % Gets the subject-specific channel definition.
    elec             = my_fixsens ( sensmeta.elec, trialdata.label );
    
    
    % Gets the position of the channels.
    [ ~, eindex ]    = ismember ( trialdata.label, elec.label );
    eindex           = eindex ( eindex > 0 );
    chanpos          = elec.chanpos ( eindex, : );
    
    % Gest the spatial filter for the surface Laplacian.
    [ ~, wLap ]      = my_sphsplint ( chanpos );
    
    % Gets the indices of the EEG channels.
    chindex          = ismember ( trialdata.label, elec.label );
    
    % Applies the filter to each trial.
    for tindex = 1: numel ( trialdata.trial )
        trialdata.trial { tindex } ( chindex, : ) = -wLap * trialdata.trial { tindex } ( chindex, : );
    end
    
%     % Defines a montage for the surface Laplacian.
%     montage          = [];
%     montage.tra      = -wLap;
%     montage.labelold = elec.label ( eindex );
%     montage.labelnew = elec.label ( eindex );
%     
%     trialdata        = ft_apply_montage ( trialdata, montage, 'feedback', 'no' );
    
    
    fprintf ( '  Saving the data.\n' );
    
    % Stores the new trial data.
    sensdata.trialdata = trialdata;
    
    % Saves the sensor data.
    save ( '-v6', sprintf ( '%s%s_%s%s_%s', config.path.slap, sensdata.subject, sensdata.task, sensdata.stage, sensdata.channel ), '-struct', 'sensdata' )
end
