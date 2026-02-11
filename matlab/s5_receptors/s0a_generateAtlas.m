clc
clear
close all

% Adds the functions folders to the path.
% addpath( fullfile ( fileparts (pwd), 'functions' ) );

% Read config from json file
config = load_config('config_s5_receptors.json');

% Add Bruña´s functions to the path
% addpath( fullfile ( config.path.meeg_analysis, 'script','functions' ) );

% MNI template
config.template = fullfile (config.path.meeg_analysis, 'script', 's2_sources','template.mat');


% Adds FieldTrip to the path, if required.
addpath ( config.path.ft_path )
ft_defaults

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'freesurfer', 1, 1 );

% Disables the FT feedback.
global ft_default;
ft_default.showcallinfo = 'no';
ft_default.checkconfig  = 'silent';

% Loads the AAL atlas.
atlasAAL = ft_read_atlas ( fullfile(config.path.ft_path, 'template/atlas/aal/ROI_MNI_V4.nii') );

% Removes the cerebellum and vermis.
atlasAAL.tissue ( atlasAAL.tissue > 90 ) = 0;
atlasAAL.tissuelabel = atlasAAL.tissuelabel ( 1: 90 );


% Loads the MNI-based template.
template = load ( config.template );

% Converts the grid to MNI voxel coordinates.
voxelGrid               = ft_convert_units ( template.grid, 'mm' );
voxelGrid               = ft_transform_geometry ( inv ( atlasAAL.transform ), voxelGrid );
voxelGrid.pos           = max ( round ( voxelGrid.pos ), 1 );

% Stores the label for each source in the grid.
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


% Saves the template.
save ( '-v6', 'template_LORETA_AAL', '-struct', 'template' );
