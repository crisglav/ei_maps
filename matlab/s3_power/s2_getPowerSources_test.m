clc
clear
close all

% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );
addpath ( sprintf ( '%s/functions/',  pwd ) );

% Read config from json file
config = load_config( fullfile('..','..','config_s3.json') );

% Sets the paths.
config.path.meg     = fullfile( config.path.project_root, 'data', 'segments');
config.path.beam    = fullfile( config.path.project_root, 'data', 'sources', 'lcmv');
config.path.pow     = fullfile( config.path.project_root, 'data', 'sources', 'power');
config.path.patt     = '*.mat';

% Action when the task have already been processed.
config.overwrite  = false;

% Name of the beamformer filter to use.
config.beamformer = 'Broadband';

% Taper to use.
config.taper      = 'dpss';
config.tapsmofrq  = 0.5;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( "C:\Users\Cristina\repos\fieldtrip" )

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );

% Loads the template.
template = load ( 'template.mat' );

% Creates and output folder, if needed.
if ~exist ( config.path.pow, 'dir' ), mkdir ( config.path.pow ); end

% Gets the list of subjects.
files    = dir ( fullfile ( config.path.beam, config.path.patt ) );

% Goes through each subject.
file = 1;

% Loads the MEG data and the beamformer information.
filename         = files ( file ).name;
[ ~, basename ]  = fileparts ( filename );

beamformer       = load ( fullfile ( config.path.beam,  basename ), 'subject', 'task', 'stage', 'channel', 'whitener', 'lambda' );

% if exist ( fullfile ( config.path.pow, sprintf ( '%s_%s_%s_w%s_r%s_%s.mat', beamformer.subject, beamformer.task, beamformer.channel, beamformer.whitener, beamformer.lambda ( 1: end - 1 ), config.taper ) ), 'file' ) && ~config.overwrite
%     fprintf ( 1, 'Ignoring subject ''%s'', task ''%s'', channel group ''%s'' (already calculated).\n', beamformer.subject, beamformer.task, beamformer.channel );
%     continue
% end

% Lists the MEG files.
sensfile         = dir ( fullfile ( config.path.meg, sprintf ( '%s_%s_%s*.mat',beamformer.subject, beamformer.task, beamformer.stage ) ) );

% if isempty ( sensfile )
%     fprintf ( 1, 'Ignoring subject ''%s'', task ''%s'', channel group ''%s'' (no MEG data).\n', beamformer.subject, beamformer.task, beamformer.channel );
%     continue
% end

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
size(rawft)

% Gets the raw Fourier transform of the data.
rawft            = reshape ( rawft, [], ntrial, nchan, nfreq );
size(rawft)
rawft            = permute ( rawft, [ 3 4 2 1 ] );
size(rawft)
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

%%%%%%%%%%%%%%% NEW %%%%%%%%%%%%%%%%%%

% Use only source positions inside the brain
source_ = [];
source_.label = source.label;
source_.pos   = source.pos(source.inside,:);
source_.inside = source.inside(source.inside);
source_.unit   = source.unit;
source_.filter = source.filter(source.inside);
source_.cov = source.cov(source.inside);
source_.pow = source.pow(source.inside);

% Extract virtual channel data - direction of max power 
cfg = [];
cfg.pos = source_.pos;
cfg.method = 'svd'; % Combine orientations of the spatial filter
vdata = ft_virtualchannel(cfg,trialdata,source_);

% Estimate power spectra at the virtual data
cfg              = [];
cfg.foilim       = bandinfo.edges;
cfg.method       = 'mtmfft';
cfg.taper        = 'dpss';
cfg.tapsmofrq    = config.tapsmofrq;
cfg.output       = 'power';
cfg.keeptrials   = true;
power            = myft_freqanalysis ( cfg, vdata );
srcpow_cg = permute ( power.powspctrm, [2 3 1] );


% ------------------------------------
% Now do get one virtual channel per orientation. Calculate the fourier coefficients
% per vchan and ori. Sum the powspectrm for the three orientations.

% Extract virtual channel data for each of the 3 orientations
cfg = [];
cfg.pos = source_.pos;
cfg.method = 'none';
vdata3d = ft_virtualchannel(cfg,trialdata,source_);

% Estimate fourier coefficients and compute fourier spectra by hand.
cfg              = [];
cfg.foilim       = bandinfo.edges;
cfg.method       = 'mtmfft';
cfg.taper        = 'dpss';
cfg.tapsmofrq    = config.tapsmofrq;
cfg.output       = 'fourier';
cfg.keeptrials   = true;
freqvdata3d       = myft_freqanalysis ( cfg, vdata3d );

% Gets the number of nsource * ori
nvchan            = numel ( freqvdata3d.label );

% Gets the raw Fourier transform of the data.
rawftv            = freqvdata3d.fourierspctrm;
size(rawftv)
% Separate ntap ntrial
rawftv            = reshape ( rawftv, [], ntrial, nvchan, nfreq );
size(rawftv)
rawftv            = permute ( rawftv, [ 3 4 2 1 ] );
size(rawftv)

% Initializes the source spectra matrix.
srcpow2           = zeros ( nsource, nfreq, ntrial, 'like', single (1) );
%%
% Goes throug each taper.
for tindex = 1: ntaper
    
    % Get current taper
    tapft            = rawftv ( :, :, :, tindex );
    size(tapft)

    % Rearrange to separate the three orientations
    srcft            = reshape ( tapft, nori, nsource, nfreq, ntrial);
    size(rawftv)

    % Gets the power spectra.
    tappow           = abs ( srcft ) .^ 2;
    size (tappow)

    % Combines all the orientations.
    tappow           = sum ( tappow, 1 );
    size (tappow)

    tappow           = permute ( tappow, [ 2 3 4 1 ] );
    size (tappow)

    % Adds the taper to the total spectra.
    srcpow2           = srcpow2 + tappow;
end

% Divides the taper-averages by the number of tapers.
srcpow2           = srcpow2 / ntaper;

%% Plotting
% check difference between srcpow and srcpow2
isrc = 1000;
figure;
plot(freqdata.freq, srcpow(isrc,:,1));
hold on;
plot(freqdata.freq, srcpow_cg(isrc,:,1));
legend("Filter*sensorfft","virtualdata1d maxpow->fft")

figure;
plot(freqdata.freq, srcpow(isrc,:,1));
hold on;
plot(freqdata.freq, srcpow2(isrc,:,1,:));
legend("Filter*sensorfft","virtualdata3d -> fft sum 3 ori")

%%
srcpow3           = zeros ( nsource, nfreq, ntrial, 'like', single (1) );

% Goes throug each taper.
for tindex = 1: ntaper
    
    % Get current taper
    tapft            = rawftv ( :, :, :, tindex );
    size(tapft)

    % Rearrange to separate the three orientations
    srcft            = reshape ( tapft, nori, nsource, nfreq, ntrial);
    size(rawftv)

    % Gets the power spectra.
    tappow           = abs ( srcft ) .^ 2;
    size (tappow)

    % % Combines all the orientations.
    % tappow           = sum ( tappow, 1 );
    % size (tappow)

    tappow           = permute ( tappow, [ 2 3 4 1 ] );
    size (tappow)

    % Adds the taper to the total spectra.
    srcpow3           = srcpow3 + tappow;
end

% Divides the taper-averages by the number of tapers.
srcpow3           = srcpow3 / ntaper;

figure;
plot(freqdata.freq, srcpow(isrc,:,1));
hold on;
plot(freqdata.freq, sum(srcpow3(isrc,:,1,:),4));
hold on;
plot(freqdata.freq, srcpow3(isrc,:,1,1));
hold on;
plot(freqdata.freq, srcpow3(isrc,:,1,2));
hold on;
plot(freqdata.freq, srcpow3(isrc,:,1,3));
legend("Filter*sensorfft", "virtualdata3d -> fft sum 3 ori", "virtualdata3d 1->fft", "virtualdata3d 2->fft", "virtualdata3d 3->fft")


figure;
plot(freqdata.freq, srcpow(isrc,:,1));
hold on;
plot(freqdata.freq, srcpow3(isrc,:,1,2));
hold on;
plot(freqdata.freq, srcpow_cg(isrc,:,1));
legend("Filter*sensorfft", "virtualdata3d 2->fft", "virtualdata1d maxpow->fft")
