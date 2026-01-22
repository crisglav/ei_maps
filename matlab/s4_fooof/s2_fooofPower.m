clc
clear
close all

addpath ( fullfile ( '..', 'functions') );

% Read config from json file
config = load_config( 'config_s4_fooof.json') ;

addpath ( fullfile ( pwd , 'fooof_matlab' ) );
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.avgpow     = fullfile( config.path.project_root, 'data', 'sources', 'avgpower');
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.patt       = '*.mat';

% Frequency band in which to fit the PSD
config.band                 = [2 45];

% Limits for peak width detection
config.peak_width_limits    = [1 12];

% Aperiodic mode (fixed or knee)
config.aperiodic_mode       = 'fixed';

% Action when the task have already been processed.
config.overwrite  = true;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Creates and output folder, if needed.
if ~exist ( config.path.fooof, 'dir' ), mkdir ( config.path.fooof ); end

% Gets the files list.
files = dir ( fullfile ( config.path.avgpow, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )

    % Preload the data
    powdata         = load ( fullfile ( config.path.avgpow, files ( findex ).name ),'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', powdata.subject, powdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, powdata.channel );

    if exist ( fullfile ( config.path.avgpow, sprintf ( '%s_%s_%s_w%s_r%s_%s_avg.mat', powdata.subject, powdata.task, powdata.channel, powdata.whitener, powdata.lambda, powdata.taper ) ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring %s (Already calculated).\n', msgtext );
        continue
    end

    fprintf ( 1, 'Working with %s.\n', msgtext );

    fprintf ( 1, '  Loading the data.\n' );

    % Loads the average power data
    powdata       = load ( fullfile ( config.path.avgpow, files ( findex ).name ) );
    nroi = length ( powdata.band.label); 

    avgpow = powdata.band.avgpow;
    freq = powdata.band.freq;

    fm_rois = struct('roi', cell(1,nroi), 'fooof', cell(1,nroi));

    fprintf ( 1, '  Fitting PSD for each ROI.\n' );

    for iroi =1:nroi
        pow = avgpow(iroi,:);

        % Fit a fooof object
        fm = fooof('freq_range', config.band ,'peak_width_limits', config.peak_width_limits ,'aperiodic_mode', config.aperiodic_mode);
        fm = add_data(fm, freq, pow);
        fm = fit(fm);

        % Store fooof object for the current roi
        fm_rois(iroi).label = powdata.band.label{iroi};
        fm_rois(iroi).fooof = fm;
        fm_rois(iroi).apexp = fm.aperiodic_params(2);

    end

    % Prepares the output.
    fooofdata          = [];
    fooofdata.subject  = powdata.subject;
    fooofdata.task     = powdata.task;
    fooofdata.channel  = powdata.channel;
    fooofdata.whitener = powdata.whitener;
    fooofdata.lambda   = powdata.lambda;
    fooofdata.taper    = powdata.taper;
    fooofdata.fm       = fm_rois;

    % Save the data
    save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_w%s_r%s_%s_fooof.mat', fooofdata.subject, fooofdata.task, fooofdata.channel, fooofdata.whitener, fooofdata.lambda, fooofdata.taper ) ) , '-struct', 'fooofdata' );
end
