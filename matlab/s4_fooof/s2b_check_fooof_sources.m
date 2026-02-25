% clc
clear
close all

% Adds the functions to the path.
addpath ( fullfile ( pwd , '..', 'functions' ) );
addpath ( 'fooof_matlab' );
% addpath ( 'script_tests' );

% Read config from json file
config = load_config( fullfile ( '..', 'config_megtusalen.json' ) );

% Adds Bruña's functions to path
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.log        = fullfile( config.path.project_root, 'logs');
config.path.figs.roi   = fullfile( config.path.project_root, 'figs', 'fooof','roi');
config.path.figs.apexp = fullfile( config.path.project_root, 'figs', 'fooof','apexp');
config.path.patt       = 'UMEC-241*.mat';

% Additional config
config.printfig = false;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% % Load fs brain with AAL areas marked
% srcatlas = load('FS average - myAAL.mat');

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
logfile = fullfile(config.path.log, 'fooof_error_log.txt');

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
    if ~isprop(fooofdata.fm, 'group_results')
        fprintf('   Skip.\n')
        continue;
    end
    rmse = cellfun(@(x) x.error(3), fooofdata.fm.group_results);
    r2 = cellfun(@(x) x.r_squared, fooofdata.fm.group_results);

    if config.printfig
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
    end

    % Log sources whose R2 is less than a threshold
    bad_sources = cortical_idx(r2<config.r2_thres);
    % ---- Append to log file ----
    fid = fopen(logfile, 'a');
    if fid == -1
        warning('Could not open log file: %s', logfile);
    else
        if isempty(bad_sources)
            fprintf(fid, '[%s] OK  | %s | nBad=0 | r2_thres=%.2f\n', ...
                datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
                sprintf('%s %s', fooofdata.subject, fooofdata.task), ...
                config.r2_thres);
        else
            fprintf(fid, '[%s] BAD | %s | nBad=%d | r2_thres=%.2f | idx=[%s]\n', ...
                datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
                sprintf('%s %s', fooofdata.subject, fooofdata.task), ...
                numel(bad_sources), config.r2_thres, ...
                sprintf('%d ', bad_sources));
        end
        fclose(fid);
    end

    % Plot PSDs with poor fitting
    if any(r2 < config.r2_thres)
        fig = fooofdata.fm.plot('rois', r2 < config.r2_thres);
        ax = findobj(fig, 'Type', 'axes');
        title(ax, fooofdata.subject);
        outname = sprintf ( '%s_%s_%s_fooof_error.png', fooofdata.subject, fooofdata.task, fooofdata.channel );
        exportgraphics(ax,fullfile(config.path.figs.roi, outname));
        close(fig);
    end

    % Discard apex from PSDs with poor fitting
    apexp_clean = fooofdata.apexp(cortical);
    apexp_clean(r2 < config.r2_thres) = nan;
    apexp_new = fooofdata.apexp;
    apexp_new(cortical) = apexp_clean;
    fooofdata.apexp = apexp_new;

    % Update fooof data
    save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_fooof_sources.mat', fooofdata.subject, fooofdata.task, fooofdata.channel) ) , '-struct', 'fooofdata' );




    % % Extract rois of the atlas
    % mask = zeros(size(cortical_idx));
    % 
    % % Plot fooofed power spectrum at each roi
    % for iRoi=1:length(config.roi)
    % 
    %     % Get all sources from this roi
    % 
    %     roi_mask = ismember(template.grid.area, config.roi(iRoi));
    %     roi_label = template.atlas.name{config.roi(iRoi)};
    %     roi_idx = find(roi_mask);
    % 
    %     [~,idx] = intersect(cortical_idx, roi_idx);
    %     mask(idx) = 1;
    % 
    %     fig = fooofdata.fm.plot('rois',logical(mask));
    % 
    %     % Fooof object
    %     % fm_roi = fm(iRoi).fooof;
    %     % fig = fm_roi.plot;
    %     ax = findobj(fig, 'Type', 'axes');
    %     title(ax, roi_label);
    %     outname = sprintf ( '%s_%s_%s_fooof_%d.png', fooofdata.subject, fooofdata.task, fooofdata.channel, iRoi );
    %     % exportgraphics(ax,fullfile(config.path.figs.roi, outname));
    %     % % close(fig);
    % end

    
    % % Extract aperiodic exponents in the available regions of the atlas fs
    % % brain
    % apexp = [ fooofdata.fm.apexp]';
    % mask = logical(map.match);
    % apexp = apexp(mask);
    % 
    % % Plot aperiodic exponents
    % plot_brain_hemispheres(apexp,srcatlas)
    % 
    % % Saves the figure.
    % print ( '-dpng', fullfile ( config.path.figs.apexp, sprintf ( '%s_%s_%s_w%s_r%s_%s_fooof.png', fooofdata.subject, fooofdata.task, fooofdata.channel, fooofdata.whitener, fooofdata.lambda, fooofdata.taper ) ) )
    % 
end


