clc
clear
close all

% Adds general functions to the path.
addpath ( fullfile ( '..', 'functions') );

% Adds template folders to the path
addpath ( fullfile ( '..', 'templates') );

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

% Sets the paths.
config.path.power     = fullfile( config.path.project_root, 'data', 'sources', 'power');
config.path.figs       = fullfile( config.path.project_root, 'figs', 'sources', 'power');
config.path.patt     = '*.mat';

config.savefig       = false;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )


% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );

% Gets the template.
template = load ( 'template.mat' );

% Generates the output folder, if needed.
if ~exist ( config.path.figs, 'dir' ), mkdir ( config.path.figs ); end

% Gets the files list.
files = dir ( fullfile ( config.path.power, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )
    
    % Loads the MRI data and extracts the masks.
    powdata       = load ( fullfile ( config.path.power, files ( findex ).name ) );
    
    alphapow      = sum ( powdata.band.sources.pow ( :, powdata.band.sources.freq >= 8 & powdata.band.sources.freq < 12 ), 2 );
    allpow        = sum ( powdata.band.sources.pow, 2 );
    
    relpow        = alphapow ./ allpow;
    
    grid          = template.grid;
    grid.pow      = relpow;
    
    cfg           = [];
    cfg.parameter = 'pow';
    
    mrigrid       = ft_sourceinterpolate ( cfg, grid, template.mri );
    
    cfg           = [];
    cfg.funparameter = 'pow';
    cfg.location  = [ +0.00, -0.06, +0.00 ];
    
    ft_sourceplot ( cfg, mrigrid );
    
    % Saves the figure.
    print ( '-dpng', fullfile ( config.path.figs, sprintf ( '%s_%s_%s.png', powdata.subject, powdata.task, powdata.channel ) ) )
    
    if config.savefig
        savefig ( fullfile ( configu.path.figs, sprintf ( '%s_%s_%s.fig', powdata.subject, powdata.task, powdata.channel ) ) )
    end
    
    close all
    
    
    cfg              = [];
    cfg.funparameter = 'pow';
    cfg.method       = 'slice';
    
    ft_sourceplot ( cfg, mrigrid );
    
    % Saves the figure.
    print ( '-dpng', fullfile ( config.path.figs, sprintf ( '%s_%s_%s_slices.png', powdata.subject, powdata.task, powdata.channel ) ) )
    
    close all
    clc
end
