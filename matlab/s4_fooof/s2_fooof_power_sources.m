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

% Sets the paths.
config.path.pow        = fullfile( config.path.project_root, 'data', 'sources', 'power');
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.log        = fullfile( config.path.project_root, 'logs');
config.path.patt       = '*.mat';

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Loads AAL template
template = load ( 'template_AAL.mat' );

% Extract cortical regions from the template
cortical = ismember(template.grid.area, config.roi);

% Creates and output folder, if needed.
if ~exist ( config.path.fooof, 'dir' ), mkdir ( config.path.fooof ); end

% Create log folder if needed
if ~exist( config.path.log, 'dir' ), mkdir ( config.path.log ); end

% Create log file
logfile = fullfile( config.path.log, 'fooof_log.txt');

diary(logfile)
diary on
fprintf('\n\n');
fprintf('=====================================================\n');
fprintf('New run started at %s\n', datetime("now"));
fprintf('=====================================================\n\n');

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

    % Save the data
    save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_fooof_sources.mat', fooofdata.subject, fooofdata.task, fooofdata.channel) ) , '-struct', 'fooofdata' );
    clear fooofdata powdata fg
end
