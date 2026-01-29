clc
clear
close all

% Read config from json file
config = load_config( 'config_famOC_dropbox.json') ;

addpath ( fullfile ( pwd , 'fooof_matlab' ) );
addpath ( fullfile ( pwd , 'script_tests' ) );
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.figs       = fullfile( config.path.project_root, 'figs', 'fooof');
config.path.patt       = '*.mat';

% Action when the task have already been processed.
config.overwrite  = true;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% % Define rois in template_AAL template
% config.hipo = true;
% 
% if config.hipo
%     % AAL with hipocampus and parahipocampus.
%     roi = [ 1: 16 19: 20 23: 28 31: 40 43: 70 79: 90 ];
% else
%     % AAL without hipocampus and parahipocampus.
%     roi = [ 1: 16 19: 20 23: 28 31: 36 43: 70 79: 90 ];
% end

% Load fs brain with AAL areas marked
srcatlas = load('FS average - myAAL.mat');


% Load label map between AAL templates (MNI-foofeddata and fs brains)
map = readtable("map_aaal_labels.csv");

% Creates and output folder, if needed.
if ~exist ( config.path.figs, 'dir' ), mkdir ( config.path.figs ); end

% Gets the files list.
files = dir ( fullfile ( config.path.fooof, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )
    
    % Preload the data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ), 'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', fooofdata.subject, fooofdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, fooofdata.channel );

    if exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_w%s_r%s_%s_fooof.mat', fooofdata.subject, fooofdata.task, fooofdata.channel, fooofdata.whitener, fooofdata.lambda, fooofdata.taper ) ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring %s (Already calculated).\n', msgtext );
        continue
    end

    fprintf ( 1, 'Working with %s.\n', msgtext );

    fprintf ( 1, '  Loading the data.\n' );

    % Load fooof data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ));
    
    % Extract aperiodic exponents in the available regions of the atlas fs
    % brain
    apexp = [ fooofdata.fm.apexp]';
    mask = logical(map.match);
    apexp = apexp(mask);

    % Plot aperiodic exponents
    plot_brain_hemispheres(apexp,srcatlas)

    % Saves the figure.
    print ( '-dpng', fullfile ( config.path.figs, sprintf ( '%s_%s_%s_w%s_r%s_%s_fooof.png', fooofdata.subject, fooofdata.task, fooofdata.channel, fooofdata.whitener, fooofdata.lambda, fooofdata.taper ) ) )
    
    close all

end


