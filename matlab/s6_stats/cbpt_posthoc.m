clc
clear
close all

% Adds the functions and templates to the path.
addpath ( fullfile ( '..', 'functions') );
addpath ( fullfile ( '..', 'templates') );
addpath ( fullfile ('functions'));

config.path.meeg_analysis = 'C:\Users\Cristina\repos\meeg_analysis';
config.path.ft_path = 'C:\Users\Cristina\repos\fieldtrip';

% Defines the input and output paths.
config.path.stats     = fullfile( '..','..','results', 'stats', 'anova', 'regress_age_no');
config.contrast = 'MCIneg-MCI-AD';
config.path.patt  = ['*' config.contrast '.mat'];


% Sets the paths.
config.path.project_root = 'C:\Users\Cristina\megtusalen';
config.path.fooofL1      = fullfile( config.path.project_root, 'L1', 'data', 'sources', 'fooof_py');
config.path.fooofL2      = fullfile(  config.path.project_root, 'L2', 'data', 'sources', 'fooof_py');
config.path.patt         = '*_sources.mat';
config.path.sample       = fullfile( '..', '..', 'data', 'participants_real.xlsx');
config.path.ft_path      = 'C:\Users\Cristina\repos\fieldtrip';
config.path.stats        = fullfile( '..','..','results', 'stats', config.test, ['regress_age_' config.regress_age] );


% Load template
config.template        = 'template_AAL';
config.roi = [1:40, 43:70, 79:90]'; % Only cortical sources
template         = load ( config.template );
cortical_mask = ismember(template.grid.area,config.roi);

% Adds, if needed, the FieldTrip folder to the path.
addpath ( config.path.ft_path )
ft_defaults

% Load the apexp data


% Lists the stats file
files = dir ( fullfile ( config.path.stats, config.path.patt ) );

% Loads the results for the statistics.
statdata = load ( fullfile ( config.path.stats, files ( 1 ).name ) );
stats      = statdata.stats;

% If no clusters continue
if all(isnan(stats.stat))
    error('No clusters.')
end

% If no significant clusters continue
if isempty(find(stats.prob<0.05, 1))
    error('No significant clusters.')
end

cluster = stats.mask > 0 & stats.prob <= 0.05;

% % In case there are more than one cluster do all this
% index      = any ( stats.mask, 1 );
% index      = cumsum ( index );
% index      = index > 0 & index <= max ( index );
% 
% cluster ( :, ~index ) = 0;
% cluster = mean ( cluster ( :, index ), 2 ) > 0.20;
% cluster = sum ( cluster ( :, index ), 2 );
% cluster = double ( cluster );

% Find all the rois that belong to the cluster
statrois = unique(template.grid.area(cluster));

for iroi =1: length(statrois)

end
    



    
    stats.mask = stats.mask > 0 & stats.prob <= 0.05;
    stats.mask ( :, ~index ) = 0;
    stats.mask = mean ( stats.mask ( :, index ), 2 ) > 0.20;
    stats.stat = sum ( stats.stat ( :, index ), 2 );
    stats.mask = double ( stats.mask );


    % Non-significant results are plotted as semi-transparent.
    stats.mask ( stats.mask == 0 ) = 0.1;


    % Interpolates the stats data to the surface.
    cfg           = [];
    cfg.parameter = { 'mask' 'stat' };
    cfg.method    = 'nearest';
    cfg.maxdist   = 0.01;

    statssurfl    = my_grid2surf ( cfg, stats, 'surface_white_left.mat',  'surface_inflated_left_caret.mat' );
    statssurfr    = my_grid2surf ( cfg, stats, 'surface_white_right.mat', 'surface_inflated_right_caret.mat' );

    % Plots the stats in the brain surface.
    if strcmp(statdata.test,'anova')
        colorbarlabel = 'f statistic';
    else
        colorbarlabel = 't statistic';
    end

    my_plotbrains ( statssurfl, statssurfr, colorbarlabel)

    % Saves the figure.
    print ( '-r150', '-dpng', fullfile( config.path.figs, sprintf('%s %s %s - a%.3f - %ip.png', config.contrast, statdata.test, statdata.metric, statdata.alpha, statdata.nperm ) ) )
    close

    if strcmp(statdata.test,'anova')
        % Goes through each pair.
        for pindex = 1: numel ( statdata.pstats )

            % Gets the results for the current pair.
            stats      = statdata.stats;
            stats.stat = statdata.pstats ( pindex ).stat;
            stats.prob = statdata.pstats ( pindex ).prob;

            % If no clusters continue
            if all(isnan(stats.stat))
                continue
            end

            % If no significant clusters continue
            if isempty(find(stats.prob<0.05, 1))
                continue
            end

            index      = any ( stats.mask, 1 );
            index      = cumsum ( index );
            index      = index > 0 & index <= max ( index );
            stats.mask = stats.mask > 0 & stats.prob <= 0.05;
            stats.mask ( :, ~index ) = 0;
            stats.mask = mean ( stats.mask ( :, index ), 2 ) > 0.20;
            stats.stat = -sum ( stats.stat ( :, index ), 2 );
            stats.mask = double ( stats.mask );

            % Non-significant results are plotted as semit-transparent.
            stats.mask ( stats.mask == 0 ) = 0.1;


            % Interpolates the stats data to the surface.
            cfg           = [];
            cfg.parameter = { 'mask' 'stat' };
            cfg.method    = 'nearest';
            cfg.maxdist   = 0.01;

            statssurfl    = my_grid2surf ( cfg, stats, 'surface_white_left.mat',  'surface_inflated_left_caret.mat' );
            statssurfr    = my_grid2surf ( cfg, stats, 'surface_white_right.mat', 'surface_inflated_right_caret.mat' );

            % Plots the stats in the brain surface.
            my_plotbrains ( statssurfl, statssurfr, 't statistic' )

            % Saves the figure.
            print ( '-r150', '-dpng', fullfile ( config.path.figs, sprintf ( '%s %s %s - a%.3f - %ip - %s v %s.png', config.contrast, statdata.test, statdata.metric, statdata.alpha, statdata.nperm, statdata.pairs { pindex, 1 }, statdata.pairs { pindex, 2 } ) ) )
            close
        end
    end
