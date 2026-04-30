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
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );
% config.roi = [ 1: 40 43: 70 79: 90 ];

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Loads AAL template
template = load ( 'template_AAL.mat' );

% Extract cortical regions from the template
cortical = ismember(template.grid.area, config.roi);
cortical_idx = find(cortical);

sessions = {'L1','L2'};

% Goes through each session
for ses = 1: numel (sessions)

    % Sets the paths.
    config.path.pow     = fullfile( config.path.project_root, sessions{ses}, 'data', 'sources', 'power');
    config.path.fooof   = fullfile( config.path.project_root, sessions{ses}, 'data', 'sources', 'fooof');
    config.path.apexp   = fullfile( config.path.project_root, sessions{ses}, 'data', 'sources', 'apexp');
    config.path.log     = fullfile( config.path.project_root, sessions{ses}, 'logs');
    config.path.patt    = '*.mat';

    % Creates and output folder, if needed.
    if ~exist ( config.path.pow, 'dir' ), mkdir ( config.path.pow ); end

    % Creates and output folder, if needed.
    if ~exist ( config.path.fooof, 'dir' ), mkdir ( config.path.fooof ); end
    if ~exist ( config.path.apexp, 'dir' ), mkdir ( config.path.fooof ); end

    % Create log folder if needed
    if ~exist( config.path.log, 'dir' ), mkdir ( config.path.log ); end

    % Create logs files
    logfile = fullfile( config.path.log, 'fooof_log.txt');
    logerror= fullfile ( config.path.log, 'fooof_error_log.txt' ) ;

    diary(logfile)
    diary on
    fprintf('\n\n');
    fprintf('=====================================================\n');
    fprintf('New run started at %s\n', datetime("now"));
    fprintf('=====================================================\n\n');

   
    fid = fopen(logerror, 'a');
    fprintf('\n\n\n');
    fprintf('=====================================================\n');
    fprintf('New run started at %s\n', datetime("now"));
    fprintf('=====================================================\n\n');
    fclose(fid);


    % Gets the files list.
    files = dir ( fullfile ( config.path.pow, config.path.patt ) );
    start = 1;

    % Goes through all the files.
    for findex = start: numel ( files )

        % Preload the data
        powdata         = load ( fullfile ( config.path.pow, files ( findex ).name ),'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

        % Gets the text of the message.
        msgtext          = sprintf ( 'subject ''%s'', task ''%s''', powdata.subject, powdata.task );
        msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, powdata.channel );

        if exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_fooof_sources.mat', powdata.subject, powdata.task, powdata.channel) ), 'file' ) && ~config.overwrite
            fprintf ( 1, 'Ignoring %s (Already calculated).\n', msgtext );
            continue
        end

        fprintf ( 1, 'Working with %s.\n', msgtext );

        fprintf ( 1, '  Loading the data.\n' );

        % Loads the power data.
        powdata       = load ( fullfile ( config.path.pow, files ( findex ).name ) );

        % Create fooofgroup object and fit the power spectrum at cortical sources
        tic
        fg = fooofGroup('freq_range', config.fooofband ,'peak_width_limits', config.peak_width_limits ,'aperiodic_mode', config.aperiodic_mode);
        fg = add_data(fg, powdata.band.sources.freq, double(powdata.band.sources.pow(cortical,:)));
        fg = fit(fg);
        fprintf (1, '  Fooof fit took %.2f s.\n', toc);

        % Extract aperiodic exponent from fooofgroup object and place them at
        % cortical regions
        apexp_temp = cellfun(@(x) x.aperiodic_params(end), fg.group_results);
        apexp = nan(size(cortical));
        apexp(cortical) = apexp_temp;

        % Prepares the output.
        fooofdata          = [];
        fooofdata.subject  = powdata.subject;
        fooofdata.task     = powdata.task;
        fooofdata.channel  = powdata.channel;
        fooofdata.whitener = powdata.whitener;
        fooofdata.lambda   = powdata.lambda;
        fooofdata.taper    = powdata.taper;
        fooofdata.fm       = fg;
        fooofdata.apexp    = apexp;

        % Get R squared from the modelled PSDs
        r2 = cellfun(@(x) x.r_squared, fooofdata.fm.group_results);

        % Discard apex from PSDs with poor fitting
        apexp_clean = fooofdata.apexp(cortical);
        apexp_clean(r2 < config.r2_thres) = nan;
        apexp = fooofdata.apexp;
        apexp(cortical) = apexp_clean;
        fooofdata.apexp_clean = apexp;

        % Log sources whose R2 is less than a threshold
        bad_sources = cortical_idx(r2<config.r2_thres);

        fid = fopen(logerror, 'a');
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

        % Save the data
        save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_fooof_sources.mat', fooofdata.subject, fooofdata.task, fooofdata.channel) ) , '-struct', 'fooofdata' );

        % Create struct to store apexp with its grid
        grid = [];
        grid.pos     = template.grid.pos;
        grid.dim     = template.grid.dim;
        grid.inside  = template.grid.inside;
        grid.unit    = template.grid.unit;
        grid.apexp   = apexp;

        % Convert to mm
        grid         = ft_convert_units ( grid, 'mm' );

        % Structure to 3d image
        cfg = [];
        cfg.parameter = 'apexp';
        image = ft_sourceinterpolate(cfg, grid, grid);

        % Export to nifti
        cfg = [];
        cfg.filename  = fullfile(config.path.apexp, sprintf('%s_%s_%s_apexp_clean', fooofdata.subject, fooofdata.task, fooofdata.channel));
        cfg.filetype  = 'nifti';
        cfg.parameter = 'apexp';
        ft_sourcewrite(cfg, image);

        clear fooofdata powdata fg

    end
end