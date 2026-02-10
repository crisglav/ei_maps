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

% Plot mni template
cfg = [];
ft_sourceplot(cfg, mni152);

% Gets the receptor map
duboisfile = 'C:\Users\Cristina\neuromaps-data\annotations\dubois2015\abp688\MNI152\source-dubois2015_desc-abp688_space-MNI152_res-1mm_feature.nii.gz';
ft_filetype(duboisfile);
dubois = ft_read_mri ( duboisfile );

% Plot receptor map
cfg = [];
ft_sourceplot ( cfg, dubois )

% Check max and min
max_value = max(max(max(dubois.anatomy)));
min_value = min(min(min(dubois.anatomy)));
%%
template = load(fullfile ( config.path.meeg_analysis, 'script', 's2_sources', 'template.mat') );
%% 
dubois_src = dubois;

% receptor values are usually in dubois.anatomy after ft_read_mri
dubois_src.pow = dubois.anatomy;
dubois_src = rmfield(dubois_src, 'anatomy');   % optional, avoids confusion

cfg = [];
cfg.method        = 'ortho';      % 'slice' or 'ortho' are common
cfg.anaparameter  = 'anatomy';    % anatomy/background
cfg.funparameter  = 'pow';        % functional overlay
cfg.funcolormap   = 'hot';        % or 'jet', etc.
cfg.funcolorlim   = 'maxabs';     % or [min max]
cfg.opacitymap    = 0.2;     % makes low values more transparent
cfg.opacitylim    = 'auto';       % or [low high]

ft_sourceplot(cfg, dubois_src, mni152);

%%
cfg = [];
cfg.parameter = 'pow';
dubois_rs = ft_volumereslice(cfg, dubois_src);   % reslice to canonical grid if needed
