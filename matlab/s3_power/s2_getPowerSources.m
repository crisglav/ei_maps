clc
clear
close all

% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );

% Read config from json file
config = load_config( 'config_megtusalen.json' );

% Sets the paths.
config.path.meg     = fullfile( config.path.project_root, 'data', 'segments');
% config.path.beam    = fullfile( config.path.project_root, 'data', 'sources', 'beamformers');
config.path.beam    = fullfile( config.path.project_root, 'data', 'sources', 'lcmv');
config.path.pow     = fullfile( config.path.project_root, 'data', 'sources', 'power');
config.path.patt     = '*.mat';

% Action when the task have already been processed.
config.overwrite  = false;

% Name of the beamformer filter to use.
config.beamformer = 'BroadbandLow05';

% Taper to use.
% config.taper      = 'hann';
config.taper      = 'dpss';
config.tapsmofrq  = 0.5;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );

% Loads the template.
template = load ( 'template.mat' );

% Creates and output folder, if needed.
if ~exist ( config.path.pow, 'dir' ), mkdir ( config.path.pow ); end

% Gets the list of subjects.
files    = dir ( fullfile ( config.path.beam, config.path.patt ) );

% Goes through each subject.
for file = 1: numel ( files )
    
    % Loads the MEG data and the beamformer information.
    filename         = files ( file ).name;
    [ ~, basename ]  = fileparts ( filename );
    
    beamformer       = load ( fullfile ( config.path.beam,  basename ), 'subject', 'task', 'stage', 'channel', 'whitener', 'lambda' );
    
    if exist ( fullfile ( config.path.pow, sprintf ( '%s_%s_%s_w%s_r%s_%s.mat', beamformer.subject, beamformer.task, beamformer.channel, beamformer.whitener, beamformer.lambda ( 1: end - 1 ), config.taper ) ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring subject ''%s'', task ''%s'', channel group ''%s'' (already calculated).\n', beamformer.subject, beamformer.task, beamformer.channel );
        continue
    end
    
    % Look for MEG file
    sensfile = dir( fullfile ( config.path.meg, sprintf ( '%s*.mat',beamformer.subject ) ) );

    % % Lists the MEG files.
    % sensfile         = dir ( fullfile ( config.path.meg, sprintf ( '%s_%s_%s*.mat',beamformer.subject, beamformer.task, beamformer.stage ) ) );
    
    if isempty ( sensfile )
        fprintf ( 1, 'Ignoring subject ''%s'', task ''%s'', channel group ''%s'' (no MEG data).\n', beamformer.subject, beamformer.task, beamformer.channel );
        continue
    end
    
    fprintf ( 1, 'Working on subject ''%s'', task ''%s'', channel group ''%s''.\n', beamformer.subject, beamformer.task, beamformer.channel );
    
    fprintf ( 1, '  Loading data.\n' );
    
    sensfile          = sensfile (1).name;
    
    sensdata         = myft_load ( fullfile ( config.path.meg, sensfile ) );
    beamformer       = load ( fullfile ( config.path.beam, basename ) );
    
    % Gets the number of padding samples of the data.
    padding          = round ( sensdata.trialinfo.trialpad (1) * sensdata.trialdata.fsample );
    
    
    % Keeps only the requested band.
    bandinfo         = beamformer.band;
    bandinfo         = bandinfo ( strcmpi ( { bandinfo.name }, config.beamformer ) );
    
    % Gets the beamformer information.
    source           = bandinfo.sources;
    filter           = cat ( 3, source.filter {:} );
    filter           = permute ( filter, [ 1 3 2 ] );
    
    % Gets the data dimensions.
    nori             = size ( filter, 1 );
    nsource          = size ( filter, 2 );
    
    % Reshapes the filter to allow matrix multiplication.
    filter           = reshape ( filter, nori * nsource, [] );
    
    
    % Selects only the channels present in the beamformer filter.
    cfg              = [];
    cfg.channel      = source.label;
    cfg.trials       = 'all';
    
    trialdata        = ft_selectdata ( cfg, sensdata.trialdata );
    
    % Removes the padding.
    trialdata        = myft_rmpad ( trialdata, sensdata.trialinfo.trialpad );
    
    
    fprintf ( 1, '  Calculating the spectra in sensor space.\n' );
    
    % Gets the spectra.
    cfg              = [];
    cfg.foilim       = bandinfo.edges;
    cfg.method       = 'mtmfft';
    cfg.taper        = config.taper;
    cfg.tapsmofrq    = config.tapsmofrq;
    cfg.output       = 'fourier';
    
    freqdata         = myft_freqanalysis ( cfg, trialdata );
    
    % Gets the data dimensions.
    nchan            = numel ( freqdata.label );
    nfreq            = numel ( freqdata.freq );
    ntrial           = numel ( trialdata.time );
    ntaper           = mean ( freqdata.cumtapcnt );
    
    % Gets the order of the channels in the beamformer filter.
    chanorder        = my_matchstr ( freqdata.label, source.label );
    
    % Gets the raw Fourier transform of the data.
    rawft            = freqdata.fourierspctrm;
    
    % Gets the raw Fourier transform of the data.
    rawft            = reshape ( rawft, [], ntrial, nchan, nfreq );
    rawft            = permute ( rawft, [ 3 4 2 1 ] );
    rawft            = rawft ( chanorder, :, :, : );
    
    
    fprintf ( 1, '  Transforming the spectra into source space.\n' );
    
%     % Re-references the data to the average.
%     warning ( 'Re-referencing the data to the average of all valid channels. Please confirm this data is EEG.' )
%     rawft            = rawft - mean ( rawft, 1 );
    
    % Initializes the source spectra matrix.
    srcpow           = zeros ( nsource, nfreq, ntrial, 'like', single (1) );
    
    % Goes throug each taper.
    for tindex = 1: ntaper
        
        % Gets the sensor-space Fourier transform for the taper.
        tapft            = rawft ( :, :, :, tindex );
        
        % Goes to source space.
        srcft            = filter * tapft ( :, : );
        srcft            = reshape ( srcft, nori, nsource, nfreq, ntrial );
        
        % Gets the power spectra.
        tappow           = abs ( srcft ) .^ 2;
        
        % Combines all the orientations.
        tappow           = sum ( tappow, 1 );
        tappow           = permute ( tappow, [ 2 3 4 1 ] );
        
        % Adds the taper to the total spectra.
        srcpow           = srcpow + tappow;
    end
    
    % Divides the taper-averages by the number of tapers.
    srcpow           = srcpow / ntaper;
    
    % Averages through trials.
    srcpow           = mean ( srcpow, 3 );
    ntrial           = 1;
    
    
    % Creates the sources structure from the template.
    source           = template.grid;
    inside           = source.inside;
    npos             = numel ( inside );
    
    % Stores the spectrum in FieldTrip form.
    pow              = nan ( npos, nfreq, ntrial, 'single' );
    pow ( inside, :, : ) = srcpow;
    
    source.pow       = pow;
    source.normpow   = bsxfun ( @rdivide, pow, sum ( pow, 2 ) );
    source.freq      = freqdata.freq;
    source.dimord    = 'pos_freq';
    
    bandinfo.sources = source;
    
    
    fprintf ( 1, '  Saving the power data.\n' );
    
    % Prepares the output.
    powdata          = [];
    powdata.subject  = beamformer.subject;
    powdata.task     = beamformer.task;
    powdata.channel  = beamformer.channel;
    powdata.whitener = beamformer.whitener;
    powdata.lambda   = beamformer.lambda;
    powdata.taper    = config.taper;
    powdata.band     = bandinfo;
    
    % Saves the data.
    save ( '-v6', fullfile ( config.path.pow, sprintf ( '%s_%s_%s', powdata.subject, powdata.task, powdata.channel ) ), '-struct', 'powdata' );
end
