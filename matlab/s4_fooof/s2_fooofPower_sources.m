clc
clear
close all

addpath ( fullfile ( '..', 'functions') );

% Read config from json file
config = load_config( 'config_famOC_dropbox.json') ;

addpath ( fullfile ( pwd , 'fooof_matlab' ) );
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.pow        = fullfile( config.path.project_root, 'data', 'sources', 'power');
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.patt       = '*.mat';

% Frequency band in which to fit the PSD
config.band                 = [2 45];

% Limits for peak width detection
config.peak_width_limits    = [1 12];

% Aperiodic mode (fixed or knee)
config.aperiodic_mode       = 'fixed';

% Atlas AAL and cortical rois (without hippocampus)
config.template = 'template_AAL.mat';
config.roi = [ 1: 16 19: 20 23: 28 31: 36 43: 70 79: 90 ];

% Action when the task have already been processed.
config.overwrite  = false;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Creates and output folder, if needed.
if ~exist ( config.path.fooof, 'dir' ), mkdir ( config.path.fooof ); end

% Extract cortical sources from the AAL atlas
template = load ( config.template );
cortical = ismember(template.grid.area, config.roi);

% Gets the files list.
files = dir ( fullfile ( config.path.pow, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )

    % Preload the data
    powdata         = load ( fullfile ( config.path.pow, files ( findex ).name ),'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', powdata.subject, powdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, powdata.channel );

    if exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_fooof_sources.mat', powdata.subject, powdata.task, powdata.channel) ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring %s (Already calculated).\n', msgtext );
        continue
    end

    fprintf ( 1, 'Working with %s.\n', msgtext );

    fprintf ( 1, '  Loading the data.\n' );

    % Loads the power data.
    powdata       = load ( fullfile ( config.path.pow, files ( findex ).name ) );
    sources = powdata.band.sources;

    % Indices of cortical sources according the AAL template
    idx = find(cortical);

    % Initialize variables
    fooofed = cell(1,size(sources.inside,1));
    apexp  = nan(1,size(sources.inside,1));

    % We are modelling the spectra only at cortical sources because
    % otherwise takes long
    fprintf ( 1, '  Modelling the power spectra at cortical sources.\n' );
    tic 
    for i = 1 : sum(cortical)
        % Extract the power spectrum for the current source
        pow = double ( sources.pow ( idx(i) ,: ) );

        % Fit a fooof object to pow
        fm = fooof ( 'freq_range', config.band ,'peak_width_limits', config.peak_width_limits ,'aperiodic_mode', config.aperiodic_mode);
        fm = add_data ( fm, sources.freq, pow);
        fm = fit(fm);

        % Store fooof object
        fooofed{idx(i)} = fm;
        apexp(idx(i)) = fm.aperiodic_params(2);
    end
    t = toc;
    fprintf (1, '  Took %.2f s.\n', t);

    % Prepares the output.
    fooofdata          = [];
    fooofdata.subject  = powdata.subject;
    fooofdata.task     = powdata.task;
    fooofdata.channel  = powdata.channel;
    fooofdata.whitener = powdata.whitener;
    fooofdata.lambda   = powdata.lambda;
    fooofdata.taper    = powdata.taper;
    fooofdata.fm       = fooofed;
    fooofdata.apexp    = apexp;

    % Save the data
    save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_fooof_sources.mat', fooofdata.subject, fooofdata.task, fooofdata.channel) ) , '-struct', 'fooofdata' );
end
