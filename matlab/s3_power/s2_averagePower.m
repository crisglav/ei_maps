clc
clear
close all

% Adds general functions to the path.
addpath ( fullfile ( '..', 'functions') );

% Adds template folders to the path
addpath ( fullfile ( '..', 'templates') );

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

% Sets the paths.
config.path.pow     = fullfile( config.path.project_root, 'data', 'sources', 'power');
config.path.avgpow  = fullfile( config.path.project_root, 'data', 'sources', 'avgpower');
config.path.patt    = '*.mat';

% Action when the task have already been processed.
config.overwrite  = true;

% Defines the template to use.
config.template   = 'template_AAL';

% load template
template = load ( config.template, 'grid', 'atlas' );

% Gets the number of rois.
nrois   = numel ( template.atlas.name );

% Creates and output folder, if needed.
if ~exist ( config.path.avgpow, 'dir' ), mkdir ( config.path.avgpow ); end

% Gets the files list.
files = dir ( fullfile ( config.path.pow, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )

    % Pre-loads the data.
    powdata         = load ( fullfile ( config.path.pow, files ( findex ).name ), 'subject', 'task', 'channel', 'whitener', 'lambda', 'taper' );
    
    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', powdata.subject, powdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, powdata.channel );
    
    if exist ( fullfile ( config.path.pow, sprintf ( '%s_%s_%s_avg.mat', powdata.subject, powdata.task, powdata.channel ) ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring %s (Already calculated).\n', msgtext );
        continue
    end
    
    fprintf ( 1, 'Working with %s.\n', msgtext );
    
    fprintf ( 1, '  Loading the data.\n' );

    % Loads the power data.
    powdata       = load ( fullfile ( config.path.pow, files ( findex ).name ) );
    nfreq = numel ( powdata.band.sources.freq );

    % Initialize power structure
    pow =  zeros ( nrois , nfreq );

    % Average power for each roi
    for iRoi = 1:nrois

        roi_mask = ismember ( template.grid.area, iRoi );
        pow_roi = powdata.band.sources.pow ( roi_mask, : );

        pow (iRoi, : ) = mean ( pow_roi );
    end

    % Save average power in each roi
    fprintf ( 1, '  Saving average power data.\n' );

    % Prepares the output.
    avgpow = powdata;
    banddata = powdata.band;

    banddata         = rmfield ( banddata, 'sources' );
    banddata         = rmfield ( banddata, 'label' );
    banddata.label   = template.atlas.name;
    banddata.nick    = template.atlas.nick;
    banddata.avgpow  = pow;
    banddata.freq    = powdata.band.sources.freq;

    avgpow.band = banddata;

    % Save the data
    save ( '-v6', fullfile ( config.path.avgpow,  sprintf ( '%s_%s_%s_avg.mat', powdata.subject, powdata.task, powdata.channel )) , '-struct', 'avgpow' );


end
