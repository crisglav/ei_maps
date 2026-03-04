clc
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
config.path.apexp      = fullfile( config.path.project_root, 'data', 'sources', 'apexp');
config.path.log        = fullfile( config.path.project_root, 'logs');
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
if ~exist ( config.path.apexp, 'dir' ), mkdir ( config.path.apexp ); end


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

    % Discard apex from PSDs with poor fitting
    apexp_clean = fooofdata.apexp(cortical);
    apexp_clean(r2 < config.r2_thres) = nan;
    apexp = fooofdata.apexp;
    apexp(cortical) = apexp_clean;
    fooofdata.apexp_clean = apexp;

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

    % Update fooof data
    save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_fooof_sources.mat', fooofdata.subject, fooofdata.task, fooofdata.channel) ) , '-struct', 'fooofdata' );

    % Create struct to store apexp with its grid
    source = [];
    source.pos     = template.grid.pos;
    source.dim     = template.grid.dim;
    source.inside  = template.grid.inside;
    source.apexp   = apexp;

    % Interploate apexp on template mri
    cfg = [];
    cfg.parameter = 'apexp';
    source_int = ft_sourceinterpolate(cfg, source, template.mri);

    % Export to nifti
    cfg = [];
    cfg.filename  = fullfile(config.path.apexp, sprintf('%s_%s_%s_apexp_clean', fooofdata.subject, fooofdata.task, fooofdata.channel));
    cfg.filetype  = 'nifti';
    cfg.parameter = 'apexp';
    ft_sourcewrite(cfg, source_int);

end


