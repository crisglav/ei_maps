clc
clear
close all

% Adds the functions and templates to the path.
addpath ( fullfile ( '..', 'templates') );
addpath ('functions');

% Defines the groups to compare.
config.group = {'FHneg', 'FHpos'};
% config.group = {'SCDneg', 'SCDpos'};
% config.group = {'MCIneg', 'MCI', 'AD'};
% config.group = {'SCDneg', 'SCDpos', 'MCIneg', 'MCI', 'AD'};


% % Sets the options for the statsitics.
config.test = 'ancova'; % 'anova'
config.statistic       = 'myft_statfun_anova';
config.tail            = 1;
config.clustertail     = 1;
config.correcttail     = 'no';

% Regress out age ('joint_all', 'joint_groups', 'separate', 'no')
config.regress_age = 'no';

% Percentage of positions from a roi that have to have a value in order to impute a
% missing value (dealing with nans in apexp)
config.threshnanrois = 50;

% Defines the template.
config.template        = 'template_AAL';
config.roi = [1:40, 43:70, 79:90]'; % Only cortical sources

% Define the metric
if strcmp(config.regress_age, 'no')
    config.metric = 'apexp';
else
    config.metric = 'apexp_res';
end

% Sets the paths.
config.path.project_root = 'C:\Users\Cristina\megtusalen';
config.path.fooofL1      = fullfile( config.path.project_root, 'L1', 'data', 'sources', 'fooof_py');
config.path.fooofL2      = fullfile(  config.path.project_root, 'L2', 'data', 'sources', 'fooof_py');
config.path.patt         = '*_sources.mat';

config.path.metadata       = fullfile( '..', '..', 'data', 'participants_real.xlsx');

config.path.ft_path      = 'C:\Users\Cristina\repos\fieldtrip';
config.path.stats        = fullfile( '..','..','results', 'stats', config.test, ['regress_age_' config.regress_age] );


% Loads the template.
template         = load ( config.template );
cortical_mask = ismember(template.grid.area,config.roi);

% Creates and output folder, if needed.
if ~exist ( config.path.stats, 'dir' ), mkdir ( config.path.stats ); end


% Adds, if needed, the FieldTrip folder to the path.
addpath ( config.path.ft_path )
ft_defaults

%% Load data
% Load metadata and apexp data
[participants, apexp_all] = load_data(config);

% Impute nans or discard subjects
[participants, apexp_all, subject_mask] = deal_nans_apexp(config, participants, apexp_all);


%% Generates the design matrix.
design           = nan ( 1, height ( participants ) );

% Fills the design matrix.
for gindex = 1: numel ( config.group )
    hits             = ismember ( participants.group_merged, config.group{gindex} );
    design ( hits )  = gindex;

end

% Add age as a covariate
if strcmp(config.test, 'ancova')
    design ( 2, : )  = participants.age;
end

% Lists only the valid data.
valid            = all ( isfinite ( design ), 1 );

%% Fit a linear regression at each source to remove the influence of age

age = participants.age;
apexp_res = nan(size(apexp_all));
source_idx = find(cortical_mask);

switch config.regress_age

    case 'joint_all'
        % Regress out age for the whole sample
        for iSource = 1:numel(source_idx)

            col = source_idx(iSource);
            model_apexp = fitlm(age, apexp_all(:, col));
            apexp_res(:, col) = model_apexp.Residuals.Raw;

        end

    case 'joint_groups'

        % Regress out age jointly for participants included in any of the three groups
        for iSource = 1:numel(source_idx)

            col = source_idx(iSource);
            model_apexp = fitlm(age(valid), apexp_all(valid, col));
            apexp_res(valid, col) = model_apexp.Residuals.Raw;

        end

    case 'separate'

        % Regress out age separately for each group
        for iSource = 1:numel(source_idx)

            col = source_idx(iSource);

            for gindex = 1: numel ( config.group )

                hits             = ismember ( participants.group_merged, config.group{gindex} );
                model_apexp = fitlm(age(hits),apexp_all(hits,col));
                apexp_res(hits,col) = model_apexp.Residuals.Raw;

            end

        end

    case 'no'

        % Do not perform any regression
        apexp_res = apexp_all;

end


%% Create data structure for cbpt
data             = cell ( height ( participants ), 1 );
data_struct = struct();
for findex = 1: height ( participants )

    data_struct.subject = participants.participant_id{findex};

    sources          = [];
    sources.dim      = template.grid.dim;
    sources.pos      = template.grid.pos;
    sources.inside   = ismember ( template.grid.area, config.roi );
    sources.dimord   = 'pos';
    sources.unit     = template.grid.unit;
    sources.(config.metric) = apexp_res(findex,:);
    data_struct.sources  = sources;

    % Stores the data.
    data { findex }  = data_struct;
end

% Concatenates all the data.
data             = cat ( 1, data {:} );

%% CBPT

% Calculates the CBPT.
cfg                  = [];
cfg.parameter        = config.metric;
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
statdata.metric      = config.metric;
statdata.nperm       = config.nperms;
statdata.data        = data ( valid );
statdata.template    = template;
statdata.stats       = stats;
statdata.config      = cfg;


% Post-hoc tests
if strcmp(config.test, 'anova') | strcmp(config.test, 'ancova')
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
group_str = strjoin(config.group, '-');

filename = ['stats_' config.test '_regress_' config.regress_age '_' group_str '.mat'];

save ( '-v6', fullfile(config.path.stats, filename), '-struct', 'statdata' )
