% clc
clear
close all

% Adds general functions to the path.
addpath ( fullfile ( '..', 'functions') );

% Adds fooof functions to the path
addpath ( 'fooof_matlab' );

% Adds template folders to the path
addpath ( fullfile ( '..', 'templates') );

% Read config from json file
config = load_config( fullfile ( '..', 'config_megtusalen.json' ) );

% Sets the paths.
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.log        = fullfile( config.path.project_root, 'logs');
config.path.figs.roi   = fullfile( config.path.project_root, 'figs', 'fooof','roi');
config.path.figs.apexp = fullfile( config.path.project_root, 'figs', 'fooof','apexp');
config.path.patt       = 'FAM-001*_rois.mat';

% Additional config
config.createfig = true;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Loads AAL template
template = load ( 'template_AAL.mat' );

% Extract cortical regions from the template
cortical = ismember(template.grid.area, config.roi);
cortical_idx = find(cortical);

% Load AAL template in surface for plotting
srcatlas = load ( 'FS average - myAAL.mat' );

% Load label map between AAL templates (MNI-foofeddata and fs brains)
map = readtable("map_aaal_labels.csv");

% Creates and output folder, if needed.
if ~exist ( config.path.figs.roi, 'dir' ), mkdir ( config.path.figs.roi ); end
if ~exist ( config.path.figs.apexp, 'dir' ), mkdir ( config.path.figs.apexp ); end

% Gets the files list.
files = dir ( fullfile ( config.path.fooof, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )
    
    % Preload the data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ), 'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', fooofdata.subject, fooofdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, fooofdata.channel );

    if ~exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_fooof_sources.mat', fooofdata.subject, fooofdata.task, fooofdata.channel ) ), 'file' )
        fprintf ( 1, 'Fooof data was not calculated for this subject: %s.\n', msgtext );
        continue
    end

    fprintf ( 1, 'Working with %s.\n', msgtext );

    fprintf ( 1, '  Loading the data.\n' );

    % Load fooof data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ));

    % Get model error per roi
    rmse = cellfun(@(x) x.error(3), fooofdata.fm.group_results);
    r2 = cellfun(@(x) x.r_squared, fooofdata.fm.group_results);

    % Retrieve the aperiodic exponents
    apexp = fooofdata.apexp;

    % Keep only aperiodic exponents from goood model fit
    apexp_clean = fooofdata.apexp;
    apexp_clean(r2 < config.r2_thres ) = nan;

    % Keep only ROIs of the AAL atlas that are available in the surface
    % template
    mask = logical(map.match);
    apexp_clean = apexp_clean(mask);    

    % Plot aperiodic exponents on brain surface
    plot_brain_hemispheres(apexp_clean,srcatlas)

    % Saves the figure.
    print ( '-dpng', fullfile ( config.path.figs.apexp, sprintf ( '%s_%s_%s_fooof_roi.png', fooofdata.subject, fooofdata.task, fooofdata.channel ) ) )

end


