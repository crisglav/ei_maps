clc
clear
close all

% Sets the paths.
config.path.segs = '../../data/segments/';
config.path.slap = '../../data/segments_slap_hjorth/';
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
    
    % Calculates the surface Laplacian.
    cfg              = [];
    cfg.method       = 'hjorth';
    cfg.elec         = elec;
    cfg.neighbours   = sensmeta.neighbours;
    
    trialdata        = ft_scalpcurrentdensity ( cfg, trialdata );
    
    
    fprintf ( '  Saving the data.\n' );
    
    % Stores the new trial data.
    sensdata.trialdata = trialdata;
    
    % Saves the sensor data.
    save ( '-v6', sprintf ( '%s%s_%s%s_%s', config.path.slap, sensdata.subject, sensdata.task, sensdata.stage, sensdata.channel ), '-struct', 'sensdata' )
end
