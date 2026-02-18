clc
clear
close all

% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );

% Read config from json file
config = load_config( 'config_megtusalen.json' );

% Sets the paths.
config.path.pow     = fullfile( config.path.project_root, 'data', 'spectra', 'dpss_05');
config.path.figs    = fullfile( config.path.project_root, 'figs', 'spectra', 'dpss_05');
config.path.patt     = '*.mat';

% Selects which versions of the figure to save.
config.savefig       = false;

% Selects the layout to plot the data.
config.layout        = 'neuromag306mag.lay';
config.occipital     = { 'MEG1531', 'MEG1641', 'MEG1711', 'MEG1721', 'MEG1731', 'MEG1741', 'MEG1911', 'MEG1921', 'MEG1931', 'MEG1941', 'MEG2031', 'MEG2041', 'MEG2111', 'MEG2121', 'MEG2131', 'MEG2141', 'MEG2311', 'MEG2321', 'MEG2331', 'MEG2341', 'MEG2431', 'MEG2511', 'MEG2521', 'MEG2531', 'MEG2541' };

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Generates the output folder, if needed.
if ~exist ( config.path.figs, 'dir' ), mkdir ( config.path.figs ); end


% Generates the layout.
layout   = ft_prepare_layout ( config );

% Gets the list of files.
files    = dir ( fullfile ( config.path.pow, config.path.patt ) );

% Goes through each file.
for findex = 1: numel ( files )
    
    % Loads the data.
    powdata   = load ( fullfile ( config.path.pow, files ( findex ).name ) );
    freqdata  = powdata.freqdata;
    
    
    figure ( 'Position', [ 105 558 1135 420 ] )
    
    % Draws the spectra.
    cfg           = [];
    cfg.layout    = layout;
    cfg.comment   = ' ';
    
    subplot ( 2, 2, [ 1 3 ] )
    ft_multiplotER ( cfg, freqdata )
    
    
    % Draws the average occipital spectrum.
    cfg           = [];
    cfg.layout    = layout;
    cfg.channel   = config.occipital;
    
    subplot ( 2, 2, 2 )
    ft_singleplotER ( cfg, freqdata )
    title ''
    
    % Draws the alpha topology.
    cfg           = [];
    cfg.layout    = layout;
    cfg.xlim      = [ 7 12 ];
    cfg.comment   = 'no';
    
    subplot ( 2, 2, 4 )
    ft_topoplotER ( cfg, freqdata )
    
    fig = gcf;
    fig.PaperOrientation = 'portrait';
    
    % Saves the figure.
    print ( '-dpng', fullfile ( config.path.figs, sprintf ( '%s_%s%s_%s.png', powdata.subject, powdata.task, powdata.stage, powdata.channel ) ) )
    
    if config.savefig
        savefig ( fullfile ( config.path.figs, sprintf ( '%s_%s%s_%s.png', powdata.subject, powdata.task, powdata.stage, powdata.channel ) ) )
    end
    
    close all
end
