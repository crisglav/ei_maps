clc
clear
close all

%% Config
% Read config from json file
config = load_config( 'config_s4.json') ;

addpath ( fullfile ( pwd , 'functions' ) );
addpath ( fullfile ( config.path.meeg_analysis, 'script', 'functions' ) );
addpath ( fullfile ( config.path.meeg_analysis, 'script', 's4_connectivity', 'functions' ) );

% Defines the template to use.
config.template   = 'template_AAL';

% Define rois 
config.hipo = false;

if config.hipo
    % AAL with hipocampus and parahipocampus.
    roi = [ 1: 16 19: 20 23: 28 31: 40 43: 70 79: 90 ];
else 
    % AAL without hipocampus and parahipocampus.
    roi = [ 1: 16 19: 20 23: 28 31: 36 43: 70 79: 90 ];
end

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

%% Load template

% Loads the template for the label information.
template = load ( config.template, 'grid', 'atlas' );

%% Plot rois
atlas = [];
atlas.name = template.atlas.name ( roi ); 
atlas.nick = template.atlas.nick ( roi );
atlas.order = intersect ( template.atlas.order, roi, 'stable');
atlas.pos = template.atlas.pos ( roi, : );

% Reorders the data.
[ ~ , idx ] = sort ( atlas.order );
order  = zeros ( size ( atlas.order ) );
order ( idx ) = 1: numel ( atlas.order );

%% DrawNetwork
hf = figure;
ha1 = axes ( hf, 'Visible', 'off' );
set ( hf, 'Units', 'normalized' )

matrix = eye ( length (roi) );
matrix = matrix ( order, order );

% Draws the four 3D views.
cfg                  = [];
cfg.model            = 'HD';
cfg.ActiveNodeSize   = 10;
cfg.InactiveNodeSize = 5;
cfg.ShowNodesNames   = 'no';
cfg.transparency     = 0.1;
cfg.ConnLineWidth    = 1;
cfg.nodes_positions  = atlas.pos ( order, : ) * 1000;
cfg.label            = atlas.nick ( order );
cfg.ShowNodesNames   = 'no';
cfg.IntraROInodesize   = 10;
cfg.ShowROIsNames    = 'yes';
cfg.rois_names       = atlas.nick ( order);

cfg.handle          = ha1;
Draw_Network ( matrix, cfg );
