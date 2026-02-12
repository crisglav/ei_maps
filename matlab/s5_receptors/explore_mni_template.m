clc
clear
close all

% Adds the functions folders to the path.
addpath( fullfile ( fileparts (pwd), 'functions' ) );

% Read config from json file
config = load_config('config_s5_receptors.json');

% Add Bruña´s functions for source reconstruction
% addpath( fullfile ( config.path.meeg_analysis, 'script', 's2_sources', 'functions' ) );

% Add fieldtrip to path
addpath ( config.path.ft_path )
ft_defaults

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );
ft_hastoolbox ( 'freesurfer', 1, 1 );

%% Load different templates and sample receptor map

% Get the MNI 152 template 1 mm from neuromaps
mni152          = fullfile ( config.path.neuromaps_data , 'atlases', 'MNI152', 'tpl-MNI152NLin2009cAsym_res-1mm_T1w.nii.gz' );
mni152          = ft_read_mri ( mni152 );

% Get the MNI template 1mm 2009c Asymetric and brain mask downloaded from McGill website
mni_web         = fullfile ( config.path.templates, 'mni_icbm152_nlin_asym_09c', 'mni_icbm152_t1_tal_nlin_asym_09c.nii' );
mni_web         = ft_read_mri ( mni_web );
brain_mask      = fullfile ( config.path.templates, 'mni_icbm152_nlin_asym_09c', 'mni_icbm152_t1_tal_nlin_asym_09c_mask.nii' );
brain_mask      = ft_read_mri( brain_mask );

% Store the brain mask inside the anatomy file and make it logical
mni_web.brain_mask = brain_mask.anatomy > 0;

% Note that McGill template is exactly the same as the one downloaded from
% neuromaps

% Get our template 2 mm
template        = load ( fullfile ( config.path.meeg_analysis, 'script', 's2_sources','template.mat' ) );

% Get the glutamate receptor map from dubois2015
dubois          = fullfile ( config.path.neuromaps_data, 'annotations', 'dubois2015' ,'abp688', 'MNI152', 'source-dubois2015_desc-abp688_space-MNI152_res-1mm_feature.nii.gz' );
dubois          = ft_read_mri ( dubois );

%% Plot MNI templates

% Plot mni152 template with receptor map overlaying (neuromaps)
dummy             = mni152;
dummy.glu         = dubois.anatomy;
cfg               = [];
cfg.method        = 'ortho';      % 'slice' or 'ortho' are common
cfg.anaparameter  = 'anatomy';    % anatomy/background
cfg.funparameter  = 'glu';
cfg.funcolormap   = 'auto';
cfg.funcolorlim   = 'auto';
ft_sourceplot(cfg, dummy);

% Plot mni template with brain mask overlying (McGill)
cfg               = [];
cfg.method        = 'ortho';      % 'slice' or 'ortho' are common
cfg.anaparameter  = 'anatomy';    % anatomy/background
cfg.funparameter  = 'anatomy';    % dummy functional parameter
cfg.maskparameter = 'brain_mask';
cfg.funcolormap   = [1, 0, 0];    % red
cfg.opacitymap    = 'rampup';
cfg.opacitylim    = [0 2];
ft_sourceplot(cfg, mni_web);

%% Save our mni template 2mm in nifti format
% This is useful to visualize it in mricron

% First convert to mm as the MNI space is in mm, not m
outmri = ft_convert_units(template.mri,'mm');

% Remove unnecessary fields
outmri = rmfield( outmri, {'gray','white','csf','brain','skull','scalp'} );

% Write nifti file
cfg             = [];
cfg.filename    = 'template.nii.gz';
cfg.filetype    = 'nifti_gz';
cfg.parameter   = 'anatomy';
ft_volumewrite(cfg, outmri);
