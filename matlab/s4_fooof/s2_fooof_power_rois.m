clc
clear
close all
% Adds the functions to the path.
addpath ( fullfile ( '..', 'functions') );
addpath ( 'fooof_matlab' );

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

% Adds Bruña's functions to path
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.pow        = fullfile( config.path.project_root, 'data', 'sources', 'power');
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.patt       = '*.mat';

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Loads AAL template
template = load ( 'template_AAL.mat' );

% Creates and output folder, if needed.
if ~exist ( config.path.fooof, 'dir' ), mkdir ( config.path.fooof ); end

% Gets the files list.
files = dir ( fullfile ( config.path.pow, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )

    % Preload the data
    powdata         = load ( fullfile ( config.path.pow, files ( findex ).name ),'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', powdata.subject, powdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, powdata.channel );

    if exist ( fullfile ( config.path.pow, sprintf ( '%s_%s_%s.mat', powdata.subject, powdata.task, powdata.channel) ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring %s (Already calculated).\n', msgtext );
        continue
    end

    fprintf ( 1, 'Working with %s.\n', msgtext );

    fprintf ( 1, '  Loading the data.\n' );

    % Loads the power data
    powdata       = load ( fullfile ( config.path.pow, files ( findex ).name ) );
    % avgpow = nan(length(config.roi),length(powdata.band.sources.freq));

    nroi = length(config.roi);
    fm_rois = struct('roi', cell(1,nroi), 'fooof', cell(1,nroi));
    
    for iRoi = 1:length(config.roi)

        roi_mask = ismember ( template.grid.area, config.roi(iRoi) );
        pow_roi = powdata.band.sources.pow ( roi_mask, : );
        
        % Average power for each roi
        avgpow = mean ( pow_roi );

        % Fit a fooof object
        fm = fooof('freq_range', config.fooofband ,'peak_width_limits', config.peak_width_limits ,'aperiodic_mode', config.aperiodic_mode);
        fm = add_data(fm, powdata.band.sources.freq, double(avgpow));
        fm = fit(fm);

        % Store fooof object for the current roi
        fm_rois(iRoi).roi = config.roi(iRoi);
        fm_rois(iRoi).label = template.atlas.name{config.roi(iRoi)};
        fm_rois(iRoi).fooof = fm;
        fm_rois(iRoi).apexp = fm.aperiodic_params(2);
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
    save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_fooof_rois.mat', fooofdata.subject, fooofdata.task, fooofdata.channel ) ) , '-struct', 'fooofdata' );
end
