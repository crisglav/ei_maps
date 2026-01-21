clc
clear
close all

% Read config from json file
config = load_config( 'config_s4.json') ;

addpath ( fullfile ( pwd , 'fooof_matlab' ) );
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.avgpow     = fullfile( config.path.project_root, 'data', 'sources', 'avgpower');
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.patt       = '*.mat';

% Action when the task have already been processed.
config.overwrite  = false;

% Fooof parameters
config.band = [2 45];
config.peak_width_limits = [1 12];
config.aperiodic_mode = 'fixed';

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Gets the template.
template = load ( 'template_AAL.mat' );

% Creates and output folder, if needed.
if ~exist ( config.path.fooof, 'dir' ), mkdir ( config.path.fooof ); end

% Gets the files list.
files = dir ( fullfile ( config.path.avgpow, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )

    % Loads the average power data
    powdata       = load ( fullfile ( config.path.avgpow, files ( findex ).name ) );
    nroi = numel ( powdata.band.roi); 

    avgpow = powdata.band.avgpow;
    freq = powdata.band.freq;

    aperiodic_exponents = zeros (1,nroi);


    for iroi =1:nroi
        pow = avgpow(iroi,:);

        % Fit a fooof object in the 2 - 40 Hz freq range
        fm = fooof('freq_range', config.band ,'peak_width_limits', config.peak_width_limits ,'aperiodic_mode', config.aperiodic_mode);
        fm = add_data(fm, freq, pow);
        fm = fit(fm);

        % Store the aperiodic exponent for the current ROI
        aperiodic_exponents(iroi) = fm.aperiodic_params(2);

    end


    % Plot aperiodic exponent across the brain
    grid          = template.grid;
    grid.apexp    = aperiodic_exponents;
    
    cfg           = [];
    cfg.parameter = 'apexp';
    
    mrigrid       = ft_sourceinterpolate ( cfg, grid, template.mri );
    
    cfg           = [];
    cfg.funparameter = 'apexp';
    % cfg.location  = [ +0.00, -0.06, +0.00 ];
    
    ft_sourceplot ( cfg, mrigrid );
    
    % Saves the figure.
    % print ( '-dpng', fullfile ( config.path.figs, sprintf ( '%s_%s_%s_%s_r%s_%s.png', powdata.subject, powdata.task, powdata.channel, powdata.whitener, powdata.lambda, powdata.taper ) ) )
    
    % if config.savefig
    %     savefig ( fullfile ( sprintf ( '%s_%s_%s_%s_r%s_%s.fig', powdata.subject, powdata.task, powdata.channel ) ) )
    % end
    
    close all
    
    
    cfg              = [];
    cfg.funparameter = 'pow';
    cfg.method       = 'slice';
    
    ft_sourceplot ( cfg, mrigrid );
    
    % Saves the figure.
    print ( '-dpng', fullfile ( config.path.figs, sprintf ( '%s_%s_%s_w%s_r%s_%s_slices.png', powdata.subject, powdata.task, powdata.channel, powdata.whitener, powdata.lambda, powdata.taper ) ) )
    


    % Save the data
    save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_w%s_r%s_%s_fooof.mat', powdata.subject, powdata.task, powdata.channel, powdata.whitener, powdata.lambda, powdata.taper )) , '-struct', 'avgpow' );
end
