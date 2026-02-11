clc
clear
close all

% Adds the functions folders to the path.
addpath( fullfile ( fileparts (pwd), 'functions' ) );

% Read config from json file
config = load_config('config_s5_receptors.json');

% Add Bruña´s functions for source reconstruction
addpath( fullfile ( config.path.meeg_analysis, 'script', 's2_sources', 'functions' ) );

% Defines the files locations.
config.path.mri        = fullfile( config.path.project_root, 'data', 'anatomy', 'T1');
config.path.patt = '*.nii.gz';

addpath ( config.path.ft_path )
ft_defaults

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );
ft_hastoolbox ( 'freesurfer', 1, 1 );


% Gets the MNI 152 template 1 mm.
mni152 = 'C:\Users\Cristina\neuromaps-data\atlases\MNI152\tpl-MNI152NLin2009cAsym_res-1mm_T1w.nii.gz';
mni152 = ft_read_mri ( mni152 );

% Get template.mat
template = load(fullfile (config.path.meeg_analysis, 'script', 's2_sources','template.mat'));

% MNI web + overlayed brain mask
mni_web_path = 'C:\Users\Cristina\Downloads\mni_icbm152_nlin_asym_09c_nifti\mni_icbm152_nlin_asym_09c\';
mni_web = [mni_web_path, 'mni_icbm152_t1_tal_nlin_asym_09c.nii'];
mni_web = ft_read_mri ( mni_web );
brain_mask = [mni_web_path, 'mni_icbm152_t1_tal_nlin_asym_09c_mask.nii'];
brain_mask = ft_read_mri(brain_mask);
mni_web.brain_mask = brain_mask.anatomy > 0;


% Plot mni template
cfg = [];
ft_sourceplot(cfg, mni_web);

cfg = [];
ft_sourceplot(cfg, template.mri);


cfg = [];
cfg.method        = 'ortho';      % 'slice' or 'ortho' are common
cfg.anaparameter  = 'anatomy';    % anatomy/background
cfg.funparameter  = 'anatomy';
cfg.maskparameter = 'brain_mask';
cfg.opacitymap    = 'rampup';      % optional but helpful
cfg.opacitylim    = [0 1];

ft_sourceplot(cfg, mni_web);

