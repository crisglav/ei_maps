clc
clear
close all

% Adds the functions and templates to the path.
addpath ( fullfile ( '..', 'functions') );
addpath ( fullfile ( '..', 'templates') );
% addpath ( fullfile ( '..', 's4_fooof','fooof_matlab') );

addpath ('functions');

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

% Adds Bruña's functions to path
% addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.project_root = 'C:\Users\Cristina\megtusalen';
config.path.fooofL1      = fullfile( config.path.project_root, 'L1', 'data', 'sources', 'fooof_py');
config.path.fooofL2      = fullfile(  config.path.project_root, 'L2', 'data', 'sources', 'fooof_py');
config.path.patt         = '*_sources.mat';
config.path.sample       = fullfile( '..', '..', 'data', 'participants_real.xlsx');
config.path.stats        = fullfile( '..','..','results', 'stats', 'apexp_ancova');
config.path.ft_path      = 'C:\Users\Cristina\repos\fieldtrip';


% Defines the groups to compare.
% config.group = {'FHneg', 'FHpos', 'SCDneg', 'MCIneg', 'SCD', 'MCI', 'AD'};
% config.group = {'FHneg', 'FHpos'};
% config.group = {'SCDneg', 'SCDpos'};
% config.group = {'MCIneg', 'MCI', 'AD'};
config.group = {'SCDneg', 'SCDpos', 'MCIneg', 'MCI', 'AD'};


% % Sets the options for the statsitics.
% ANOVA
config.test            = 'anova';
config.statistic       = 'myft_statfun_anova';
config.tail            = 1;
config.clustertail     = 1;
config.correcttail     = 'no';

% 
% % T-TEST
% config.test            = 'ttest';
% config.statistic       = 'ft_statfun_indepsamplesT';
% config.tail            = 0;
% config.clustertail     = 0;
% config.correcttail     = 'prob';


config.metric          = 'apexp';
config.alpha           = 0.05;

% Sets the options for cluster correction
config.clusterstatistic = 'maxsum';
config.clusterthreshold = 'parametric';
config.clustercritval   = [];
config.clusteralpha     = 0.05;

% Sets the number of permutations
config.nperms           = 10000;

% Defines the template.
config.template        = 'template_AAL';
config.roi = [1:40, 43:70, 79:90]';

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

% Convert to categorical (optional but recommended)
participants.group_merged = categorical(participants.group_merged);


%% Lists the fooof files.
filesL1 = dir(fullfile(config.path.fooofL1, config.path.patt));
filesL2 = dir(fullfile(config.path.fooofL2, config.path.patt));

files = [filesL1; filesL2];

% Extract participant_id and session from each file
file_ids = cellfun(@(x) strtok(x, '_'), {files.name}, 'UniformOutput', false)';

file_session = strings(numel(files), 1);
for i = 1:numel(files)
    if contains(files(i).folder, [filesep 'L1' filesep])
        file_session(i) = "L1";
    elseif contains(files(i).folder, [filesep 'L2' filesep])
        file_session(i) = "L2";
    end
end

% Matches metadata with the right data
participant_keys = strcat(string(participants.participant_id), "_", string(participants.session));
file_keys        = strcat(string(file_ids), "_", file_session);

% Keep only files present in participants table, preserving participants order
[is_included, file_order] = ismember(participant_keys, file_keys);

participants = participants(is_included, :);
files        = files(file_order(is_included));

% Safety check
ordered_file_ids = cellfun(@(x) strtok(x, '_'), {files.name}, 'UniformOutput', false)';
assert(isequal(string(ordered_file_ids), string(participants.participant_id)), ...
    'Files and participants are not in the same order.');

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
    sources.apexp_clean = fooofdata.apexp_clean;
    sources.dimord   = 'pos';
    % sources.power    = rawpow;
    % sources.freq     = freq;
    % sources.dimord   = 'pos_freq';
    sources.unit     = template.grid.unit;

    % Modifies the data structure.
    % fooofdata          = rmfield ( fooofdata, {'task', 'channel', 'whitener', 'lambda', 'taper','fm', 'apexp','apexp_clean'} );
    fooofdata          = rmfield ( fooofdata, {'task', 'channel', 'whitener', 'lambda', 'taper', 'apexp','apexp_clean','r_squared','aperiodic_params'} );
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

% Adds the age
design ( 2, : )  = participants.age;

% Lists only the valid data.
valid            = all ( isfinite ( design ), 1 );

% Calculates the CBPT.
cfg                  = [];
cfg.parameter        = 'apexp_clean';
cfg.method           = 'montecarlo';
cfg.statistic        = config.statistic; % Bruña version, faster
% cfg.statistic        = 'ft_statfun_indepsamplesF'; % fieldtrip version
cfg.correctm         = 'cluster';
cfg.alpha            = 0.05;
cfg.tail             = config.tail;
cfg.correcttail      = config.correcttail;

cfg.clusterstatistic = 'maxsum';
cfg.clusterthreshold = 'parametric';
cfg.clustercritval   = [];
cfg.clusteralpha     = 0.05;
cfg.clustertail      = config.clustertail; % Because we are using a Fstatistic

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
statdata.test        = config.test;
statdata.metric      = config.metric;
statdata.alpha       = config.alpha;
statdata.nperm       = config.nperms;
statdata.data        = data ( valid );
statdata.template    = template;
statdata.stats       = stats;
statdata.config      = cfg;


% Post-hoc tests
if strcmp(config.test, 'anova')
    % Lists the possible pairs.
    pairs      = nchoosek ( config.group, 2 );

    % Initializes the statistics results cell.
    pstats     = cell ( size ( pairs, 1 ), 1 );

    % Goes through each pair wise comparison.
    for pindex = 1: size ( pairs, 1 )

        % Generates the design matrix.
        design           = nan ( 1, numel ( data ) );

        % Fills the design matrix.
        for gindex = 1: numel ( pairs ( pindex, : ) )
            hits             = ismember ( participants.group_merged, pairs ( pindex, gindex ) );
            design ( hits )  = numel ( pairs ( pindex, : ) ) - gindex + 1;
        end

        % Lists only the valid data.
        valid            = all ( isfinite ( design ), 1 );


        % Calculates the statistics.
        cfg.statistic        = 'ft_statfun_indepsamplesT';
        cfg.tail             = 0;
        cfg.method           = 'analytic';
        cfg.correctm         = 'no';
        cfg.design           = design ( :, valid );
        cfg.ival             = 1;

        pstats { pindex }    = ft_sourcestatistics ( cfg, data ( valid ).sources );
    end

    % Concatenates the statistics for all the pairs.
    pstats = cat ( 1, pstats {:} );

    % Add to the output
    statdata.pairs       = pairs;
    statdata.pstats      = pstats;
    statdata.config      = cfg;

end

% Saves the results of the statistics analysis.
group_str = strjoin(config.group, '-');

filename = ['stats_apexp_cbpt_' group_str '_anova.mat'];

save ( '-v6', fullfile(config.path.stats, filename), '-struct', 'statdata' )