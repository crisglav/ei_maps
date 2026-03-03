% clc
clear
close all

% Adds general functions to the path.
addpath ( fullfile ( '..', 'functions') );

% Adds fooof functions to the path
addpath ( 'fooof_matlab' );

% Adds template folders to the path
addpath ( fullfile ( '..', 'templates') );

% Read config from json file
config = load_config( fullfile ( '..', 'config_megtusalen.json' ) );

% Sets the paths.
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.log        = fullfile( config.path.project_root, 'logs');
config.path.figs.roi   = fullfile( config.path.project_root, 'figs', 'fooof','roi');
config.path.figs.apexp = fullfile( config.path.project_root, 'figs', 'fooof','apexp');
config.path.patt       = '*_sources.mat';

% Additional config
config.createfig = false;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Loads AAL template
template = load ( 'template_AAL.mat' );

% Extract cortical regions from the template
cortical = ismember(template.grid.area, config.roi);
cortical_idx = find(cortical);

% Load label map between AAL templates (MNI-foofeddata and fs brains)
% map = readtable("map_aaal_labels.csv");

% Creates and output folder, if needed.
if ~exist ( config.path.figs.roi, 'dir' ), mkdir ( config.path.figs.roi ); end
if ~exist ( config.path.figs.apexp, 'dir' ), mkdir ( config.path.figs.apexp ); end

% Create log file
logfile = fullfile ( config.path.log, 'fooof_error_log.txt' ) ;

% Write a header once per run
fid = fopen(logfile, 'a');
fprintf('\n\n\n');
fprintf('=====================================================\n');
fprintf('New run started at %s\n', datetime("now"));
fprintf('=====================================================\n\n');
fclose(fid);

% Gets the files list.
files = dir ( fullfile ( config.path.fooof, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )
    
    % Preload the data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ), 'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', fooofdata.subject, fooofdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, fooofdata.channel );

    if ~exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_fooof_sources.mat', fooofdata.subject, fooofdata.task, fooofdata.channel ) ), 'file' )
        fprintf ( 1, 'Fooof data was not calculated for this subject: %s.\n', msgtext );
        continue
    end

    fprintf ( 1, 'Working with %s.\n', msgtext );

    fprintf ( 1, '  Loading the data.\n' );

    % Load fooof data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ));
   
    % Get root mean squared error and R squared from the modelled PSDs
    rmse = cellfun(@(x) x.error(3), fooofdata.fm.group_results);
    r2 = cellfun(@(x) x.r_squared, fooofdata.fm.group_results);

    if config.createfig
        % Create figure with fixed size (in pixels)
        f1 = figure('Units', 'pixels', ...
            'Position', [100 100 1000 400], ...
            'Color', 'w');

        % Use tiledlayout for equal-sized subplots
        t = tiledlayout(1,2, ...
            'TileSpacing','compact', ...
            'Padding','compact');

        % ---- RMSE ----
        nexttile;
        histogram(rmse, 'FaceColor', [0.2 0.4 0.8]);
        title('RMSE');
        xlabel('RMSE');
        ylabel('Count');
        set(gca, 'FontSize', 12, 'Box', 'off');

        % ---- R^2 ----
        nexttile;
        histogram(r2, 'FaceColor', [0.8 0.3 0.3]);
        title('R^2');
        xlabel('R^2');
        ylabel('Count');
        set(gca, 'FontSize', 12, 'Box', 'off');

        % Shared formatting
        sgtitle(fooofdata.subject, ...
            'FontSize', 14, 'FontWeight', 'bold');

        % Save
        outname = sprintf('%s_%s_%s_fooof_error.png', ...
            fooofdata.subject, ...
            fooofdata.task, ...
            fooofdata.channel);

        exportgraphics(f1, fullfile(config.path.figs.apexp, outname), ...
            'Resolution', 300);

        close(f1);


        % Plot PSDs with poor fitting
        if any(r2 < config.r2_thres)
            f2 = fooofdata.fm.plot('rois', r2 < config.r2_thres);
            ax = findobj(f2, 'Type', 'axes');
            title(ax, fooofdata.subject);
            outname = sprintf ( '%s_%s_%s_fooof_error.png', fooofdata.subject, fooofdata.task, fooofdata.channel );
            exportgraphics(ax,fullfile(config.path.figs.roi, outname));
            close(f2);
        end

    end

end


