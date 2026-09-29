% Checks for differences between the same group across different datasets
%
% Cristina Gil Ávila, 23/09/2026
clc
clear
close all
date = datetime('now','Format','yyyyMMdd');

% Group
group = 'HC';

% Adds the functions and templates to the path.
addpath ('functions');

% Read config from json file
txt = fileread( fullfile ('..', 'config_megtusalen.json' ));
config = jsondecode(txt);

% Set datasets accordingly
if strcmp(group,'MCI')
    config.dataset = {'UMEC','NEMOS'};
end
if strcmp(group,'HC')
    config.dataset = {'FAM', 'UMEC','NEMOS'};
end

% Sets the options for the statsitics.
config.test            = 'ancova';
config.statistic       = 'myft_statfun_anova';
config.tail            = 1;
config.clustertail     = 1;
config.correcttail     = 'no';

% Creates and output folder, if needed.
config.path.stats        = fullfile( '..','..','results', 'stats','ancova');
if ~exist ( config.path.stats, 'dir' ), mkdir ( config.path.stats ); end

% Loads the source grid with AAL atlas.
template = load ( fullfile( '..', '..', 'data', 'templates', 'template_AAL.mat' ) );
cortical_mask = ismember(template.grid.area, config.roi);

% Adds, if needed, the FieldTrip folder to the path.
addpath ( config.path.ft_path )
ft_defaults

%% Load participants metadata
participants = readtable(config.path.participants, 'PreserveVariableNames', true );
participants.diagnosis = categorical (participants.diagnosis);

% Recode values
participants.diagnosis(participants.diagnosis == "FH") = "HC";

% Select participants with this diagnosis
mask = ismember(participants.diagnosis, group);
participants = participants(mask, :);

% Discard participants with poor model fit
participants = participants(participants.fooofok,:);


%% Locate apexp files
participants.apexp_files = participants.participant_id;

for pid=1:height(participants)
    participant_id = participants.participant_id{pid};
    session = participants.session{pid};

    apexp_folder = fullfile(config.path.project_root, session, config.path.fooof);
    file = dir(fullfile(apexp_folder,[participant_id '*_imp.mat']));
    participants.apexp_files{pid} = fullfile(file.folder, file.name);

end

%% Load aperiodic exponent data

apexp_all = nan(height(participants), numel(cortical_mask));

for pid=1:height(participants)
    fooofdata = load ( participants.apexp_files{pid});
    apexp_all(pid,:) = fooofdata.apexp_imp;
end

%% Generates the design matrix.
design           = nan ( 1, height ( participants ) );

% Fills the design matrix.
for gindex = 1: numel ( config.dataset )
    hits = startsWith(participants.participant_id, config.dataset{gindex});
    design ( hits )  = gindex;
end

% Add age as a covariate
if strcmp(config.test, 'ancova')
    design ( 2, : )  = participants.age;
end

% Lists only the valid data.
valid            = all ( isfinite ( design ), 1 );

%% Create data structure for cbpt
data             = cell ( height ( participants ), 1 );
data_struct = struct();
for pid = 1: height ( participants )

    data_struct.subject = participants.participant_id{pid};

    sources          = [];
    sources.dim      = template.grid.dim;
    sources.pos      = template.grid.pos;
    sources.inside   = ismember ( template.grid.area, config.roi );
    sources.dimord   = 'pos';
    sources.unit     = template.grid.unit;
    sources.apexp_imp = apexp_all(pid,:);
    data_struct.sources  = sources;

    % Stores the data.
    data { pid }  = data_struct;
end

% Concatenates all the data.
data             = cat ( 1, data {:} );

%% CBPT

% Calculates the CBPT.
cfg                  = [];
cfg.parameter        = 'apexp_imp';
cfg.method           = 'montecarlo';
cfg.statistic        = config.statistic;
cfg.correctm         = 'cluster';
cfg.alpha            = 0.05;
cfg.tail             = config.tail;
cfg.correcttail      = config.correcttail;

cfg.clusterstatistic = 'maxsum';
cfg.clusterthreshold = 'parametric';
cfg.clustercritval   = [];
cfg.clusteralpha     = 0.05;
cfg.clustertail      = config.clustertail;

cfg.computecritval   = 'yes';
cfg.computestat      = 'yes';
cfg.computeprob      = 'no';
cfg.feedback         = 'text';
cfg.numrandomization = 10000;
cfg.design           = design ( :, valid );
if strcmp(config.test,'anova')
    cfg.ivar             = 1;
end
if strcmp (config.test, 'ancova')
    cfg.ivar = [1,2];
end
cfg.randomseed       = 10;

% Sets the number of permutations
config.nperms           = 10000;

stats                = ft_sourcestatistics ( cfg, data ( valid ).sources );

% Prepares the output.
statdata             = [];
statdata.test        = config.test;
statdata.nperm       = config.nperms;
statdata.data        = data ( valid );
statdata.template    = template;
statdata.stats       = stats;
statdata.config      = cfg;


% Post-hoc tests
if strcmp(config.test, 'anova') | strcmp(config.test, 'ancova')
    % Lists the possible pairs.
    pairs      = nchoosek ( config.dataset, 2 );

    % Initializes the statistics results cell.
    pstats     = cell ( size ( pairs, 1 ), 1 );

    % Goes through each pair wise comparison.
    for pindex = 1: size ( pairs, 1 )

        % Generates the design matrix.
        design           = nan ( 1, numel ( data ) );

        % Fills the design matrix.
        for gindex = 1: numel ( pairs ( pindex, : ) )
            hits             = startsWith(participants.participant_id, pairs ( pindex, gindex ));
            design ( hits )  = gindex;
        end

        % Lists only the valid data.
        valid            = all ( isfinite ( design ), 1 );


        % Calculates the statistics.
        cfg.statistic        = 'ft_statfun_indepsamplesT';
        cfg.tail             = 0;
        cfg.method           = 'analytic';
        cfg.correctm         = 'no';
        cfg.design           = design ( :, valid );
        cfg.ivar             = 1;

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
dataset_str = strjoin(config.dataset, '-');

filename = strcat('stats_', config.test, '_', group, '_', dataset_str, '_', string(date), '.mat');

save ( fullfile(config.path.stats, filename), '-struct', 'statdata' )
