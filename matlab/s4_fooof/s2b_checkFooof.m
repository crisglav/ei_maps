clc
clear
close all

% Read config from json file
config = load_config( 'config_s4.json') ;

addpath ( fullfile ( pwd , 'fooof_matlab' ) );
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.figs       = fullfile( config.path.project_root, 'figs', 'fooof');
config.path.patt       = '*.mat';

% Action when the task have already been processed.
config.overwrite  = false;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Load fs brain with AAL areas marked
srcatlas = load('FS average - myAAL.mat');


% Creates and output folder, if needed.
if ~exist ( config.path.figs, 'dir' ), mkdir ( config.path.figs ); end

% Gets the files list.
files = dir ( fullfile ( config.path.fooof, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )

    % Loads fooof data for each roi of the AAL atlas
    load ( fullfile ( config.path.fooof, files ( findex ).name ) );
    apexp = [fm_rois.apexp];
    rois = [fm_rois.roi];
    labels = {fm_rois.label};
end

%% Plot aperiodic values on the fs brain

% Gets the left and right hemispheres.
left_hemi  = srcatlas.mesh.bnd (1);
right_hemi = srcatlas.mesh.bnd (2);

% Load label map between AAL templates
map = readtable("map_aal_labels.xls");

% Extract rois
ismember(labels,cellstr(map.old_labels));

atlas_labels = srcatlas.atlas.name;


% Make sure that my roi ids correspond to the matched label on the fs
% template

ismember(my_labels, srcatlas.atlas.name)

% Assign the parameter value to its corresponding area
nroi = length(apexp);
for iroi = 1:nroi
    left_hemi.param = left_hemi.area == rois(iroi);
    maskl = left_hemi.area;
end

% Colors the nodes according to the atlas area.
left_hemi.color  = double(left_hemi.area);
right_hemi.color = double(right_hemi.area);

% Plots the two meshes.
figure;

% First subplot: left hemisphere mesh
ax1 = axes('Position', [0.00, 0.5, 0.6, 0.6]);
hold on;
ft_plot_mesh(left_hemi, 'facecolor', [1 1 1]);
material dull;
lighting gouraud;
view(115, 10);
camlight;
%rotate3d;
hold off
axis off;
%text(0, 0, feat{1}, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');


% Second subplot: right hemisphere mesh
ax2 = axes('Position', [0.00, 0.0, 0.6, 0.6]);
hold on;
ft_plot_mesh(left_hemi, 'facecolor', [1 1 1]);
material dull;
lighting gouraud;
view(-115, 10);
camlight;
%rotate3d;
axis off;
hold off;
drawnow

 % Third subplot: left hemisphere mesh
ax3 = axes('Position', [0.4, 0.5, 0.6, 0.6]);
hold on;
ft_plot_mesh(right_hemi, 'facecolor', [1 1 1]);
material dull;
lighting gouraud;
view(-115, 10);
camlight;
rotate3d;
axis off;
hold off;
drawnow;


% Fourth subplot: right hemisphere mesh
ax4 = axes('Position', [0.4, 0.0, 0.6, 0.6]);
hold on;
ft_plot_mesh(right_hemi, 'facecolor', [1 1 1]);
material dull;
lighting gouraud;
view(115, 10);
camlight;
rotate3d;
axis off;
drawnow;
