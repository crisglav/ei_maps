clc
clear
close all

% Read config from json file
config = load_config( 'config_s4.json') ;

addpath ( fullfile ( pwd , 'fooof_matlab' ) );
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.avgpow     = fullfile( config.path.project_root, 'data', 'sources', 'avgpower');
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.patt       = '*.mat';

% Fooof parameters
config.band                 = [2 45];
config.peak_width_limits    = [1 12];
config.aperiodic_mode       = 'fixed';

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Creates and output folder, if needed.
if ~exist ( config.path.fooof, 'dir' ), mkdir ( config.path.fooof ); end

% Gets the files list.
files = dir ( fullfile ( config.path.avgpow, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )

    % Loads the average power data
    powdata       = load ( fullfile ( config.path.avgpow, files ( findex ).name ) );
    nroi = numel ( powdata.band.roi); 

    avgpow = powdata.band.avgpow;
    freq = powdata.band.freq;

    fm_rois = struct('roi', cell(1,nroi), 'fooof', cell(1,nroi));


    for iroi =1:nroi
        pow = avgpow(iroi,:);

        % Fit a fooof object
        fm = fooof('freq_range', config.band ,'peak_width_limits', config.peak_width_limits ,'aperiodic_mode', config.aperiodic_mode);
        fm = add_data(fm, freq, pow);
        fm = fit(fm);

        % Store fooof object for the current roi
        fm_rois(iroi).roi = powdata.band.roi(iroi);
        fm_rois(iroi).label = powdata.band.label{iroi};
        fm_rois(iroi).fooof = fm;
        fm_rois(iroi).apexp = fm.aperiodic_params(2);

    end

    % Save the data
    save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_w%s_r%s_%s_fooof.mat', powdata.subject, powdata.task, powdata.channel, powdata.whitener, powdata.lambda, powdata.taper ) ) , 'fm_rois' );
end
