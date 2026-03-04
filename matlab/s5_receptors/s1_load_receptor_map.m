clc
clear
close all

% Adds general functions to the path.
addpath ( fullfile ( '..', 'functions') );

% Adds template folders to the path
addpath ( fullfile ( '..', 'templates') );

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

% Add Bruña´s functions for source reconstruction
% addpath( fullfile ( config.path.meeg_analysis, 'script', 's2_sources', 'functions' ) );

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

%% Load source model and receptor map

% Loads our MNI template 2 mm resolution with source model grid
template = load ( 'template.mat' );

% Get the glutamate receptor map from dubois2015
dubois          = fullfile ( config.path.neuromaps_data, 'dubois2015' ,'abp688', 'MNI152', 'source-dubois2015_desc-abp688_space-MNI152_res-1mm_feature.nii.gz' );
dubois          = ft_read_mri ( dubois );

%% Apply Gaussian smoothing to the receptor map
% As the resolution of the map is higher than our MEG source model, we
% blurr the map so that proximal sources have more similar values.

fwhm = 10; % 1 cm
sigma = fwhm/(2*sqrt(2*log(2)));
duboisbl = dubois;
duboisbl.anatomy = imgaussfilt3(dubois.anatomy, sigma);


% % Visualize it
% cfg               = [];
% cfg.method        = 'ortho';      % 'slice' or 'ortho' are common
% cfg.anaparameter  = 'anatomy';    % anatomy/background
% ft_sourceplot(cfg, duboisbl);

% cfg               = [];
% cfg.method        = 'ortho';      % 'slice' or 'ortho' are common
% cfg.anaparameter  = 'anatomy';    % anatomy/background
% ft_sourceplot(cfg, dubois);

%% Sample receptor values at grid positions

% Converts the template grid (in m) to mm and to MNI voxel coordinates.
voxelGrid               = ft_convert_units ( template.grid, 'mm' );
voxelGrid               = ft_transform_geometry ( inv ( duboisbl.transform ), voxelGrid );
voxelGrid.pos           = max ( round ( voxelGrid.pos ), 1 );

% Sample receptor values at grid positions
vox_indx                = sub2ind ( duboisbl.dim, voxelGrid.pos ( :, 1 ), voxelGrid.pos ( :, 2 ), voxelGrid.pos ( :, 3 ) );
value                   = duboisbl.anatomy ( vox_indx );

% Store receptor information
template.receptor          = [];
template.receptor.dubois   = value;

%% Load AAL atlas from fieldtrip
% Loads the AAL atlas.
atlasAAL = ft_read_atlas ( fullfile(config.path.ft_path, 'template', 'atlas', 'aal', 'ROI_MNI_V4.nii' ) );

% Removes the cerebellum and vermis.
atlasAAL.tissue ( atlasAAL.tissue > 90 ) = 0;
atlasAAL.tissuelabel = atlasAAL.tissuelabel ( 1: 90 );

%% Asign AAL Rois to grid positions

% Converts the template grid to MNI voxel coordinates.
voxelGrid               = ft_convert_units ( template.grid, 'mm' );
voxelGrid               = ft_transform_geometry ( inv ( atlasAAL.transform ), voxelGrid );
voxelGrid.pos           = max ( round ( voxelGrid.pos ), 1 );

% Assign an atlas label to each grid position
template.grid.area      = atlasAAL.tissue ( sub2ind ( atlasAAL.dim, voxelGrid.pos ( :, 1 ), voxelGrid.pos ( :, 2 ), voxelGrid.pos ( :, 3 ) ) );

% Initializes the area information.
template.atlas          = [];
template.atlas.atlas    = 'AAL';
template.atlas.name     = atlasAAL.tissuelabel (:);
template.atlas.pos      = zeros ( numel ( atlasAAL.tissuelabel ), 3 );
template.atlas.unit     = atlasAAL.unit;

% Calculates the centroid for each ROI.
for aindex = 1: numel ( atlasAAL.tissuelabel )
    
    % Finds all the voxels labelled as part of the area.
    voxelArea   = find ( atlasAAL.tissue == aindex );
    [ x, y, z ] = ind2sub ( atlasAAL.dim, voxelArea );
    voxelArea   = cat ( 2, x, y, z );
    
    % Gets the centroid of the area.
    centerArea  = mean ( voxelArea, 1 );
    centerArea ( :, 4 ) = 1;
    
    % Converts the voxel coordinates to MNI coordinates.
    centerArea  = ( atlasAAL.transform * centerArea' )';
    centerArea ( :, 4 ) = [];
    
    % Stores the centroid.
    template.atlas.pos  ( aindex, : ) = centerArea;
end

% Transforms the area information to grid units.
template.atlas           = ft_convert_units ( template.atlas, template.grid.unit );

%% Save template
save ( '-v6', 'template_receptors', '-struct', 'template' );

%% Plot our template with receptor map overlying
% Interpolate glutamate binding potential (in grid) to mri template for
% visualization
cfg = [];
cfg.parameter = 'glu';
cfg.interpmethod = 'nearest';
interp = ft_sourceinterpolate(cfg, template.grid, template.mri);

% Plot our template with recepot map overlying
cfg = [];
cfg.method        = 'ortho';
cfg.funparameter  = 'glu';
ft_sourceplot(cfg, interp);


% Check max and min
max_value = max(max(max(dubois.anatomy)))
min_value = min(min(min(dubois.anatomy)))

max_value = max(max(max(duboisbl.anatomy)))
min_value = min(min(min(duboisbl.anatomy)))

max_value = max(max(max(template.grid.glu)))
min_value = min(min(min(template.grid.glu)))

max_value = max(max(max(interp.glu)))
min_value = min(min(min(interp.glu)))
