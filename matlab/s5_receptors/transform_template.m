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

% Gets our template 2 mm
template = load(fullfile (config.path.meeg_analysis, 'script', 's2_sources','template.mat'));

% Gets the receptor map
duboisfile = 'C:\Users\Cristina\neuromaps-data\annotations\dubois2015\abp688\MNI152\source-dubois2015_desc-abp688_space-MNI152_res-1mm_feature.nii.gz';
dubois = ft_read_mri ( duboisfile );


% Plot mni template with receptor map overlaying
dummy = mni152;
dummy.glu = dubois.anatomy;
cfg = [];
cfg.method        = 'ortho';      % 'slice' or 'ortho' are common
cfg.anaparameter  = 'anatomy';    % anatomy/background
cfg.funparameter  = 'glu';
cfg.funcolormap = 'auto';
cfg.funcolorlim = 'auto';
% cfg.maskparameter = 'brain_mask';
% cfg.opacitymap    = 'rampup';      % optional but helpful
% cfg.opacitylim    = [0 1];
ft_sourceplot(cfg, dummy);

% Plot our tamplate with recepot map overlaying
dummy = template.mri;
dummy.glu = dubois.anatomy;
cfg = [];
cfg.method        = 'ortho';      % 'slice' or 'ortho' are common
cfg.anaparameter  = 'anatomy';    % anatomy/background
cfg.funparameter  = 'glu';
cfg.funcolormap = 'auto';
cfg.funcolorlim = 'auto';
% cfg.maskparameter = 'brain_mask';
% cfg.opacitymap    = 'rampup';      % optional but helpful
% cfg.opacitylim    = [0 1];
ft_sourceplot(cfg, dummy);

% % Save our mni template in nifti format
% outmri = ft_convert_units(template.mri,'mm');
% outmri = rmfield(outmri,{'gray','white','csf','brain','skull','scalp'});
% 
% cfg = [];
% cfg.filename = 'template.nii.gz';
% cfg.filetype = 'nifti_gz';
% cfg.parameter = 'anatomy';
% ft_volumewrite(cfg, outmri);


% Check max and min
max_value = max(max(max(dubois.anatomy)));
min_value = min(min(min(dubois.anatomy)));

%%
%%--- load atlas (yours)
atlas = ft_read_atlas(fullfile(config.path.ft_path, 'template/atlas/aal/ROI_MNI_V4.nii'));
atlas = ft_convert_units(atlas, 'mm');

% Make sure coordsys is defined (often it already is)
atlas.coordsys = 'mni';

% --- load FieldTrip's MNI anatomical template
template = ft_read_mri(fullfile(config.path.ft_path, 'template/anatomy/single_subj_T1.nii'));
template = ft_convert_units(template, 'mm');
template.coordsys = 'mni';

% --- (optional but often helpful) align atlas to template grid
cfg = [];
cfg.parameter = 'tissue';      % for a NIfTI atlas this is typically the label volume
cfg.interpmethod = 'nearest';  % keep discrete labels
atlas_rs = ft_sourceinterpolate(cfg, atlas, template);

% --- plot overlay
cfg = [];
cfg.method        = 'ortho';
cfg.funparameter  = 'tissue';
cfg.maskparameter = 'tissue';      % show only where atlas labels exist
cfg.opacitymap    = 'rampup';
cfg.atlas         = atlas;         % enables label lookup
ft_sourceplot(cfg, atlas_rs);

