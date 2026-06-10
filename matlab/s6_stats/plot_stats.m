clc
clear
close all

% Adds the functions and templates to the path.
% addpath ( fullfile ( '..', 'functions') );
addpath ( fullfile ( '..', 'templates') );

% Defines the input and output paths.
config.path.stats     = fullfile( '..','..','results', 'stats', 'ancova', 'regress_age_no');
config.path.figs      = fullfile( '..','..', 'figs', 'stats', 'ancova','regress_age_no');
config.contrast = '*';
config.path.patt  = ['*_' config.contrast '_UMEC.mat'];

config.path.ft_path = 'C:\Users\Cristina\repos\fieldtrip';

% Adds, if needed, the FieldTrip folder to the path.
addpath ( config.path.ft_path )
ft_defaults

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );

% Creates the output folder, if required.
if ~exist ( config.path.figs, 'dir' ), mkdir ( config.path.figs ), end

% Lists the files in the folder.
files = dir ( fullfile ( config.path.stats, config.path.patt ) );

% Goes through each file.
for findex = 1: numel ( files )

    % Loads the results for the statistics.
    statdata = load ( fullfile ( config.path.stats, files ( findex ).name ) );
    contrast = split(files (findex).name, '_');
    contrast = extractBefore(contrast{end}, '.');

    % Gets the main results.
    stats      = statdata.stats;

    % If no clusters continue
    if all(isnan(stats.stat))
        continue
    end

    % If no significant clusters continue
    if isempty(find(stats.prob<0.1, 1))
        continue
    end

    index      = any ( stats.mask, 1 );
    index      = cumsum ( index );
    index      = index > 0 & index <= max ( index );
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

    my_plotbrains ( statssurfl, statssurfr, 'f statistic')

    % Saves the figure.
    print ( '-r150', '-dpng', fullfile( config.path.figs, sprintf('UMEC_%s_%s_%s.png', contrast, statdata.test, statdata.metric) ) )
    close

    if strcmp(statdata.test,'anova') | strcmp(statdata.test,'ancova')
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
            stats.stat = sum ( stats.stat ( :, index ), 2 );
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
            print ( '-r150', '-dpng', fullfile ( config.path.figs, sprintf ( 'UMEC_%s_posthoc_%s - %s v %s.png', contrast, statdata.metric, statdata.pairs { pindex, 1 }, statdata.pairs { pindex, 2 } ) ) )
            close
        end
    end
end
