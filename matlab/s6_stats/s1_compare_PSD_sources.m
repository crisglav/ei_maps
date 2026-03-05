clc
clear
close all

% Adds the functions and templates to the path.
addpath ( fullfile ( '..', 'functions') );
addpath ( fullfile ( '..', 'templates') );
addpath ('functions');

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

% Adds Bruña's functions to path
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.convpow    = fullfile( config.path.megtusalen_conv, 'data', 'sources', 'power');
config.path.pow        = fullfile( config.path.project_root, 'data', 'sources', 'power');
config.path.sample     = fullfile( config.path.project_root, 'data', 'participants','participant_sample.xlsx');
config.path.stats      = fullfile( config.path.project_root, 'stats', 'power');
config.path.patt       = '*.mat';

% Defines the groups to compare.
config.group = {'HC','MCI','AD','SCD','FH'};
% config.group = {'FH+','FH-'};


% Sets the options for the statsitics.
config.statistic       = 'ft_statfun_indepsamplesF'; % ANOVA
config.alpha           = 0.05;
config.tail            = 1;
config.correcttail     = 'no';

% Sets the options for cluster correction
config.clusterstatistic = 'maxsum';
config.clusterthreshold = 'parametric';
config.clustercritval   = [];
config.clusteralpha     = 0.05;
config.clustertail      = 1;

% Sets the number of permutations
config.nperms           = 100;

% Defines the template.
config.template        = 'template_AAL';


% Adds, if needed, the FieldTrip folder to the path.
addpath ( config.path.ft_path )
ft_defaults

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );

% Loads the template.
template         = load ( config.template );

% Creates and output folder, if needed.
if ~exist ( config.path.stats, 'dir' ), mkdir ( config.path.stats ); end

% Load metadata to assign groups
participants = readtable(config.path.sample, 'PreserveVariableNames', true );
participants.group = categorical (participants.group);
participants.group_simp = categorical (participants.group_simp);
participants.project = categorical (participants.project);
participants.sex = categorical (participants.sex);

% Keep only valid metadata (with sources file, truly healthy, with
% diagnosis)
mask = participants.missing_lcmv == 0 & participants.not_healthy == 0 & ~isundefined(participants.group_simp);
participants = participants(mask,:);

% Lists the power files.
files            = dir ( fullfile ( config.path.pow, config.path.patt ) );

% Reserves memory for the power data.
data             = cell ( numel ( files ), 1 );

% Goes though each file.
for findex = 1: numel ( files )
    
    % Loads the power data.
    powdata          = load ( fullfile ( config.path.pow, files ( findex ).name ) );
    
    % Extracts the normalized power data.
    rawpow           = powdata.band.sources.normpow;
    freq             = powdata.band.sources.freq;
    
    % Builds the power definition.
    sources          = [];
    sources.dim      = template.grid.dim;
    sources.pos      = template.grid.pos;
    sources.inside   = ismember ( template.grid.area, config.rois );
    sources.power    = rawpow;
    sources.freq     = freq;
    sources.dimord   = 'pos_freq';
    sources.unit     = template.grid.unit;
    
    
    % Modifies the data structure.
    powdata          = rmfield ( powdata, 'band' );
    powdata.sources  = sources;
    
    % Stores the data.
    data { findex }  = powdata;
end

% Concatenates all the power data.
data             = cat ( 1, data {:} );

% Keep only valid data
ids = split(participants.id_dropbox, '_');
ids = ids(:,1);
index = ismember ( { data.subject }, ids );
data = data ( index );

% Handle converters, from whom we are using L2
mask_conv = participants.group == "CONV";
ids_conv = split(participants.id_dropbox(mask_conv),'_');
ids_cov = ids_conv(:,1);
index = ~ismember ( { data.subject }, ids_conv );
data = data ( index );


% Lists the conv files.
files            = dir ( fullfile ( config.path.convpow, config.path.patt ) );

% Reserves memory for the power data.
dataconv             = cell ( numel ( files ), 1 );

% Goes though each file.
for findex = 1: numel ( files )
    
    % Loads the power data.
    powdata          = load ( fullfile ( config.path.convpow, files ( findex ).name ) );
    
    % Extracts the normalized power data.
    rawpow           = powdata.band.sources.normpow;
    freq             = powdata.band.sources.freq;
    
    % Builds the power definition.
    sources          = [];
    sources.dim      = template.grid.dim;
    sources.pos      = template.grid.pos;
    sources.inside   = ismember ( template.grid.area, config.rois );
    sources.power    = rawpow;
    sources.freq     = freq;
    sources.dimord   = 'pos_freq';
    sources.unit     = template.grid.unit;
    
    
    % Modifies the data structure.
    powdata          = rmfield ( powdata, 'band' );
    powdata.sources  = sources;
    
    % Stores the data.
    dataconv { findex }  = powdata;
end

% Concatenates all the power data.
dataconv             = cat ( 1, dataconv {:} );

% Concatenate the two datasets
data = cat (1, data, dataconv);

% Matches each metadata with the right data.
order                = my_matchstr ( ids, { data.subject } );
participants         = participants ( order, : );

% Generates the design matrix.
design           = nan ( 1, numel ( data ) );

% Fills the design matrix.
for gindex = 1: numel ( config.group )
    hits             = ismember ( participants.group_simp, config.group{gindex} );
    design ( hits )  = gindex;
end

% Lists only the valid data.
valid            = all ( isfinite ( design ), 1 );

% Calculates the CBPT.
cfg                  = [];
cfg.parameter        = 'power';
cfg.method           = 'montecarlo';
cfg.statistic        = 'myft_statfun_anova';
% cfg.statistic        = 'ft_statfun_indepsamplesF';
cfg.correctm         = 'cluster';
cfg.alpha            = config.alpha;
cfg.tail             = config.tail;
cfg.correcttail      = config.correcttail;

cfg.clusterstatistic = 'maxsum';
cfg.clusterthreshold = 'parametric';
cfg.clustercritval   = [];
cfg.clusteralpha     = 0.05;
cfg.clustertail      = 1; % Because we are using a Fstatistic

cfg.computecritval   = 'yes';
cfg.computestat      = 'yes';
cfg.computeprob      = 'no';
cfg.feedback         = 'text';
cfg.numrandomization = 100;
cfg.design           = design ( :, valid );
cfg.ivar             = 1;
cfg.randomseed       = 10;

stats                = ft_sourcestatistics ( cfg, data ( valid ).sources );

% Pairwise tests
cfg.numrandomization = 1;
pairwise                = ft_sourcestatistics ( cfg, data ( valid ).sources );


% Prepares the output.
statdata             = [];
statdata.test        = config.test;
statdata.metric      = config.metric;
statdata.contrast    = sprintf ( '%s v %s', config.group );
statdata.alpha       = config.alpha;
statdata.nperm       = config.perms;
statdata.data        = data ( valid );
statdata.template    = template;
statdata.stats       = stats;
statdata.config      = cfg;

% Saves the results of the statistics analysis.
save ( '-v6', sprintf ( '%s%s - %s - %s - a%.3f - %ip.mat', config.path.stats, statdata.test, statdata.metric, statdata.contrast, statdata.alpha, statdata.nperm ), '-struct', 'statdata' )


stats_ = stats;
stats_.mask = any(stats_.mask,2);
stats_.stat = max(stats_.stat,[],2);
cfg               = [];
cfg.method        = 'cloud';
cfg.funparameter  = 'mask';
% cfg.maskparameter = 'mask';
cfg.funcolormap = 'cool';
ft_sourceplot(cfg, stats_);