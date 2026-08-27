clc
clear
close all

% Adds general functions to the path.
addpath ( fullfile ( '..', 'functions') );

% Adds power functions to the path
addpath ( 'functions' );

% Adds template folders to the path
addpath ( fullfile ( '..', 'templates') );

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );

% Loads the template.
template = load ( 'template.mat' );

sessions = {'L1','L2'};
s = {};
% Goes through each session
for ses = 1: numel (sessions)

    % Sets the paths.
    config.path.meg     = fullfile( config.path.project_root, sessions{ses}, 'data', 'segments');
    config.path.beam    = fullfile( config.path.project_root, sessions{ses}, 'data', 'sources', 'lcmv');
    config.path.patt     = '*.mat';
    % Gets the list of subjects.
    files    = dir ( fullfile ( config.path.beam, config.path.patt ) );

    min = zeros(1,numel(files));

    % Goes through each subject.
    for file = 1: numel ( files )

        % Loads the MEG data and the beamformer information.
        filename         = files ( file ).name;
        [ ~, basename ]  = fileparts ( filename );

        beamformer       = load ( fullfile ( config.path.beam,  basename ), 'subject', 'task', 'channel', 'whitener', 'lambda' );

        % Look for MEG file
        sensfile = dir( fullfile ( config.path.meg, sprintf ( '%s*.mat',beamformer.subject ) ) );

        sensfile          = sensfile (1).name;

        sensdata         = myft_load ( fullfile ( config.path.meg, sensfile ) );

        min(file) = (size(sensdata.trialdata.trial,1) * 4) / 60;
        
    end

    s{ses} = min;


end

scat = [s{1}, s{2}];

