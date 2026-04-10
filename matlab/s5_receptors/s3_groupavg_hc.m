clc
clear
close all

% Adds general functions to the path.
addpath ( fullfile ( '..', 'functions') );

% Adds template folders to the path
addpath ( fullfile ( '..', 'templates') );

% Adds fooof functions to the path
addpath ( fullfile ( '..' , 's4_fooof', 'fooof_matlab' ) );

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

% addpath ( fullfile ( pwd , 'script_tests' ) );
% addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.receptor   = fullfile( '..', '..', 'data', 'receptors');
config.path.results    = fullfile( '..', '..', 'results');
config.path.patt       = 'FAM-001*fooof_sources.mat';

% List of receptors
config.rececptors = {'dubois'};

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

%% Load source model and receptor map

% Loads our MNI template 2 mm resolution with source model grid
template = load ( 'template.mat' );

% Get the glutamate receptor map from dubois2015
dubois          = fullfile ( config.path.neuromaps_data, 'dubois2015' ,'abp688', 'MNI152', 'source-dubois2015_desc-abp688_space-MNI152_res-1mm_feature.nii.gz' );
dubois          = ft_read_mri ( dubois );

% Apply Gaussian smoothing to the receptor map
% As the resolution of the map is higher than our MEG source model, we
% blurr the map so that proximal sources have more similar values.
% fwhm = 10; % 1 cm
% sigma = fwhm/(2*sqrt(2*log(2)));
% dubois.anatomy = imgaussfilt3(dubois.anatomy, sigma);

% Sample receptor values at grid positions
% Converts the grid to MNI voxel coordinates using receptor transform.
voxel_grid               = ft_convert_units ( template.grid, 'mm' );
voxel_grid               = ft_transform_geometry ( inv ( dubois.transform ), voxel_grid );
voxel_grid.pos           = max ( round ( voxel_grid.pos ), 1 );

% Sample receptor values at grid positions
vox_indx                = sub2ind ( dubois.dim, voxel_grid.pos ( :, 1 ), voxel_grid.pos ( :, 2 ), voxel_grid.pos ( :, 3 ) );
value                   = dubois.anatomy ( vox_indx );

% Transform positions from voxel coordinates to MNI coordinates
receptor_map            = ft_transform_geometry ( dubois.transform, voxel_grid );
receptor_map.value      = value;

% Save receptor map
% save ( fullfile ( config.path.receptor, 'dubois_downsampled.mat' ), '-struct', 'receptor_map' );
%%
% Gets the fooof files list.
files = dir ( fullfile ( config.path.fooof, config.path.patt ) );

corrs = nan(1,length(files));
% Goes through all the files.
for findex = 1: numel ( files )
    
    % Preload the data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ), 'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', fooofdata.subject, fooofdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, fooofdata.channel );

    if exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_fooof_sources.mat', fooofdata.subject, fooofdata.task, fooofdata.channel ) ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring %s (Already calculated).\n', msgtext );
        continue
    end

    fprintf ( 1, 'Working with %s.\n', msgtext );

    fprintf ( 1, '  Loading the data.\n' );

    % Load fooof data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ));
    
    % Aperiodic exponent
    apexp = fooofdata.apexp_clean;

    % Extract receptor values
    value = receptor_map.value;

    % Calculate spatial correlation between receptor and aperiodic exponent
    corrs(findex) = corr(value, apexp, 'Rows','complete');

end

% save correlation to results
save( fullfile ( config.path.results, 'dubois_corrs.mat'),'corrs');

% figure,
% scatter(1:length(files),corrs);
% 
% [h,p,ci,stats] = ttest(corrs);


% Restrict glutamate distribution only to cortical sources
receptor.map.value = receptor.map.value;
template.grid.glu(isnan(apexp)) = nan;

% Interpolate glutamate binding potential (in grid) to mri template for
% visualization
cfg = [];
cfg.parameter = 'value';
cfg.interpmethod = 'nearest';
interp = ft_sourceinterpolate(cfg, template.grid, template.mri);

% Plot our template with receptor map overlying
cfg = [];
cfg.method        = 'ortho';
cfg.funparameter  = 'value';
ft_sourceplot(cfg, interp);

% Interpolate aperiodic exponent (in grid) to mri template for
% visualization
template.grid.apexp = apexp;
cfg = [];
cfg.parameter = 'apexp';
cfg.interpmethod = 'nearest';
interp = ft_sourceinterpolate(cfg, template.grid, template.mri);

% Plot our template with receptor map overlying
cfg = [];
cfg.method        = 'ortho';
cfg.funparameter  = 'apexp';
cfg.funcolorlim   = [min(apexp), max(apexp)];
ft_sourceplot(cfg, interp);