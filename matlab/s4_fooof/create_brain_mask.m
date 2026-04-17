clc
clear
close all

% Adds general functions to the path.
addpath ( fullfile ( '..', 'functions') );

% Adds template folders to the path
addpath ( fullfile ( '..', 'templates') );

% Read config from json file
config = load_config( fullfile ( '..', 'config_megtusalen.json' ) );

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Loads AAL template
template = load ( 'template_AAL.mat' );

% Create struct to store apexp with its grid
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

% Create a "brain mask" with one number per position inside the brain
ind = find(image.inside(:));
image.parcellation = zeros(size(image.inside));
image.parcellation(ind) = 1:numel(ind);

% Export parcellation in nifti
cfg = [];
cfg.filename  = fullfile('..','..','data','parcellation');
cfg.filetype  = 'nifti';
cfg.parameter = 'parcellation';
% ft_sourcewrite(cfg, image);

% Create a brain mask with one number per position for cortical sources only
cortical   = find(~ismember ( grid.area, [ 0 41 42 71 72 73 74 75 76 77 78 ] ));
image.parcellation = zeros(size(image.inside));
image.parcellation(cortical) = 1:numel(cortical);

% Export parcellation in nifti
cfg = [];
cfg.filename  = fullfile('..','..','data','parcellation_cortical');
cfg.filetype  = 'nifti';
cfg.parameter = 'parcellation';
ft_sourcewrite(cfg, image);
