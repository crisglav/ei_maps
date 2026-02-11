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

%% Plot our template with receptor map overlying

% Converts the template grid (in mm) to MNI voxel coordinates.
voxelGrid               = ft_convert_units ( template.grid, 'mm' );
voxelGrid               = ft_transform_geometry ( inv ( dubois.transform ), voxelGrid );
voxelGrid.pos           = max ( round ( voxelGrid.pos ), 1 );

% Assign receptor values to grid positions
template.grid.glu      = dubois.anatomy ( sub2ind ( dubois.dim, voxelGrid.pos ( :, 1 ), voxelGrid.pos ( :, 2 ), voxelGrid.pos ( :, 3 ) ) );

% Interpolate glutamate binding potential (in grid) to mri template (2 mm)
cfg = [];
cfg.parameter = 'glu';
cfg.interpmethod = 'nearest';
interp = ft_sourceinterpolate(cfg, template.grid, template.mri);

% Plot our template with recepot map overlaying
cfg = [];
cfg.method        = 'ortho';
cfg.funparameter  = 'glu';
ft_sourceplot(cfg, interp);

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
