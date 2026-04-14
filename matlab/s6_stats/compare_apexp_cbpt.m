clc
clear
close all

% Adds the functions and templates to the path.
addpath ( fullfile ( '..', 'functions') );
addpath ( fullfile ( '..', 'templates') );
addpath ( fullfile ( '..', 's4_fooof','fooof_matlab') );

addpath ('functions');

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

% Adds Bruña's functions to path
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.fooofL1      = fullfile( config.path.project_root, 'L1', 'data', 'sources', 'fooof');
config.path.fooofL2      = fullfile(  config.path.project_root, 'L2', 'data', 'sources', 'fooof');
config.path.sample     = fullfile( '..', '..', 'data', 'participants_real.xlsx');
config.path.stats      = fullfile( '..','..','results', 'stats', 'apexp');
config.path.patt       = '*_sources.mat';

% Defines the groups to compare.
config.group = {'FHneg', 'FHpos', 'SCDneg', 'MCIneg', 'SCD', 'MCI', 'AD'};

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
config.nperms           = 1000;

% Defines the template.
config.template        = 'template_AAL';

% Adds, if needed, the FieldTrip folder to the path.
addpath ( config.path.ft_path )
ft_defaults

% Loads the template.
template         = load ( config.template );

% Creates and output folder, if needed.
if ~exist ( config.path.stats, 'dir' ), mkdir ( config.path.stats ); end

%% Load metadata to assign groups
participants = readtable(config.path.sample, 'PreserveVariableNames', true );
participants.group = categorical (participants.group);
participants.diagnosis = categorical (participants.diagnosis);
participants.sex = categorical (participants.sex);

participants.group_merged = participants.group;

% Recode values
participants.group_merged(ismember(participants.group, ["MCIa","MCIm"])) = "MCI";
participants.group_merged(participants.group == "CONV") = "AD";
participants.group_merged(participants.group == "SCDpos") = "SCD";

% Convert to categorical (optional but recommended)
participants.group_merged = categorical(participants.group_merged);


% Lists the fooof files.
filesL1 = dir ( fullfile ( config.path.fooofL1, config.path.patt ) );

% Select only files that are included in the study
files_ids = cellfun(@(x) strtok(x, '_'), {filesL1.name}, 'UniformOutput', false);
is_included = ismember(files_ids, participants.participant_id(strcmp(participants.session,'L1')));
filesL1 = filesL1(is_included);

% Add L2 files
filesL2 = dir ( fullfile ( config.path.fooofL2, config.path.patt ) );

files = [filesL1; filesL2];

%% Reserves memory for the power data.
data             = cell ( numel ( files ), 1 );

% Goes though each file.
for findex = 1: numel ( files )
    
    % Loads the fooof data.
    fooofdata          = load ( fullfile ( files (findex).folder, files ( findex ).name ) );

    % Builds the power definition.
    sources          = [];
    sources.dim      = template.grid.dim;
    sources.pos      = template.grid.pos;
    sources.inside   = ismember ( template.grid.area, config.roi );
    sources.apexp_clean    = fooofdata.apexp_clean;
    sources.dimord   = 'pos';
    % sources.power    = rawpow;
    % sources.freq     = freq;
    % sources.dimord   = 'pos_freq';
    sources.unit     = template.grid.unit;
    
    % Modifies the data structure.
    fooofdata          = rmfield ( fooofdata, {'task', 'channel', 'whitener', 'lambda', 'taper', 'fm', 'apexp','apexp_clean'} );
    fooofdata.sources  = sources;
    
    % Stores the data.
    data { findex }  = fooofdata;
end

% Concatenates all the fooof data.
data             = cat ( 1, data {:} );

% Generates the design matrix.
design           = nan ( 1, numel ( data ) );

% Fills the design matrix.
for gindex = 1: numel ( config.group )    
    hits             = ismember ( participants.group_merged, config.group{gindex} );
    design ( hits )  = gindex;
end

% Lists only the valid data.
valid            = all ( isfinite ( design ), 1 );

% Calculates the CBPT.
cfg                  = [];
cfg.parameter        = 'apexp_clean';
cfg.method           = 'montecarlo';
cfg.statistic        = 'myft_statfun_anova'; % Bruña version, faster
% cfg.statistic        = 'ft_statfun_indepsamplesF'; % fieldtrip version
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
cfg.numrandomization = config.nperms;
cfg.design           = design ( :, valid );
cfg.ivar             = 1;
cfg.randomseed       = 10;

stats                = ft_sourcestatistics ( cfg, data ( valid ).sources );

% Prepares the output.
statdata             = [];
statdata.alpha       = config.alpha;
statdata.nperm       = config.nperms;
statdata.data        = data ( valid );
statdata.template    = template;
statdata.stats       = stats;
statdata.config      = cfg;

% Saves the results of the statistics analysis.
save ( '-v6', fullfile(config.path.stats, 'stats_apexp_cbpt.mat'), '-struct', 'statdata' )