% This script creates a nifiti image of the source model grid, where each
% source position inside the brain has a distinct number (1 to 1210)
% Image is saved in data/parcellation.nii
%
% Cristina Gil, C3N, 28/08/2026

clc
clear
close all

% Read config from json file
txt = fileread( fullfile ('..', 'config_megtusalen.json' ));
config = jsondecode(txt);

% Adds, if needed, the FieldTrip folder to the path.
addpath( config.path.ft_path )
ft_defaults;

% Loads AAL template
template = load ( fullfile( '..', '..', 'data', 'templates', 'template_AAL.mat' ));

% Create grid struct
grid = [];
grid.pos     = template.grid.pos;
grid.dim     = template.grid.dim;
grid.inside  = template.grid.inside;
grid.unit    = template.grid.unit;
grid.area    = template.grid.area;

% Convert to mm
grid         = ft_convert_units ( grid, 'mm' );

% Structure to 3d image
cfg = [];
cfg.parameter = 'area';
image = ft_sourceinterpolate(cfg, grid, grid);

% Export source grid in nifiti
image.brainmask = double(image.inside);
cfg = [];
cfg.filename  = fullfile('..', '..', 'data', 'templates', 'template');
cfg.filetype  = 'nifti';
cfg.parameter = 'brainmask';
ft_sourcewrite(cfg, image);

% Create a "brain mask" with one number per position inside the brain
ind = find(image.inside(:));
image.parcellation = zeros(size(image.inside));
image.parcellation(ind) = 1:numel(ind);

% Export parcellation in nifti
cfg = [];
cfg.filename  = fullfile('..', '..', 'data', 'templates', 'parcellation');
cfg.filetype  = 'nifti';
cfg.parameter = 'parcellation';
ft_sourcewrite(cfg, image);

% Below different versions of the 'parcellation' only taking into account
% cortical regions for the AAL2 atlas instead of the full brain.

% % Create a brain mask with one number per position for cortical sources only
% cortical   = find(~ismember ( grid.area, [ 0 41 42 71 72 73 74 75 76 77 78 ] ));
% image.parcellation = zeros(size(image.inside));
% image.parcellation(cortical) = 1:numel(cortical);
% 
% % Export parcellation in nifti
% cfg = [];
% cfg.filename  = fullfile('..','..','data','parcellation_cortical');
% cfg.filetype  = 'nifti';
% cfg.parameter = 'parcellation';
% ft_sourcewrite(cfg, image);
% 
% 
% % Create a brain mask with one number per position for cortical sources only
% rois = [
%         1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16, ...
%         19,20, ...
%         23,24,25,26,27,28, ...
%         31,32,33,34,35,36, ...
%         43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70, ...
%         79,80,81,82,83,84,85,86,87,88,89,90
%     ];
% cortical_nohipo   = find(ismember ( grid.area, rois ));
% image.parcellation = zeros(size(image.inside));
% image.parcellation(cortical_nohipo) = 1:numel(cortical_nohipo);
% 
% % Export parcellation in nifti
% cfg = [];
% cfg.filename  = fullfile('..','..','data','parcellation_cortical_nohipo');
% cfg.filetype  = 'nifti';
% cfg.parameter = 'parcellation';
% ft_sourcewrite(cfg, image);
