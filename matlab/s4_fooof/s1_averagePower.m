clc
clear
close all

% Read config from json file
config = load_config( 'config_s4.json') ;

% Sets the paths.
config.path.pow     = fullfile( config.path.project_root, 'data', 'sources', 'power');
config.path.avgpow  = fullfile( config.path.project_root, 'data', 'sources', 'avgpower');
config.path.patt    = '*.mat';

% Action when the task have already been processed.
config.overwrite  = false;

% Defines the bands to use.
config.bands      = { 'Broadband' };

% Defines the template to use.
config.template   = 'template_AAL';

% Define rois
config.hipo = true;

if config.hipo
    % AAL with hipocampus and parahipocampus.
    roi = [ 1: 16 19: 20 23: 28 31: 40 43: 70 79: 90 ];
else
    % AAL without hipocampus and parahipocampus.
    roi = [ 1: 16 19: 20 23: 28 31: 36 43: 70 79: 90 ];
end

% load template
template = load ( config.template, 'grid', 'atlas' );

% Gets the number of rois.
nrois   = numel ( roi );

% Creates and output folder, if needed.
if ~exist ( config.path.avgpow, 'dir' ), mkdir ( config.path.avgpow ); end

% Gets the files list.
files = dir ( fullfile ( config.path.pow, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )

    % Loads the power data.
    powdata       = load ( fullfile ( config.path.pow, files ( findex ).name ) );
    nfreq = numel ( powdata.band.sources.freq );

    % Initialize power structure
    pow =  zeros ( nrois , nfreq );

    % Average power for each roi
    for iRoi = 1:nrois

        roi_mask = ismember ( template.grid.area, roi(iRoi) );
        pow_roi = powdata.band.sources.pow ( roi_mask, : );

        pow (iRoi, : ) = mean ( pow_roi );
    end

    % figure
    % plot (powdata.band.sources.freq, pow)

    % Save average power in each roi

    fprintf ( 1, '  Saving average power data.\n' );

    % Prepares the output.
    avgpow = powdata;
    banddata = powdata.band;

    banddata         = rmfield ( banddata, 'sources' );
    banddata         = rmfield ( banddata, 'label' );
    banddata.label   = template.atlas.name ( roi );
    banddata.nick    = template.atlas.nick ( roi );
    banddata.roi     = roi';
    banddata.avgpow  = pow;
    banddata.freq    = powdata.band.sources.freq;

    avgpow.band = banddata;

    % Save the data
    save ( '-v6', fullfile ( config.path.avgpow,  sprintf ( '%s_%s_%s_w%s_r%s_%s_avg.mat', powdata.subject, powdata.task, powdata.channel, powdata.whitener, powdata.lambda, powdata.taper )) , '-struct', 'avgpow' );


end
