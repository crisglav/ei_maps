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

% Parameter to interpolate nan values ('interpolate','omitsources')
config.dealnan = 'interpolate'; % 'omitsources'

% Defines the groups to compare.
% config.group = {'FHneg', 'FHpos'};
% config.group = {'SCDneg', 'SCDpos'};
config.group = {'MCIneg', 'MCI', 'AD'};
% config.group = {'SCDneg', 'SCDpos', 'MCIneg', 'MCI', 'AD'};

% Defines the template.
config.template        = 'template_AAL';
config.roi = [1:40, 43:70, 79:90]'; % Only cortical sources

% % Sets the options for the statsitics.
% ANCOVA
config.test            = 'ancova';
config.statistic       = 'myft_statfun_anova';
config.tail            = 1;
config.clustertail     = 1;
config.correcttail     = 'no';

config.metric          = 'apexp';
config.alpha           = 0.05;

% Sets the options for cluster correction
config.clusterstatistic = 'maxsum';
config.clusterthreshold = 'parametric';
config.clustercritval   = [];
config.clusteralpha     = 0.05;

% Sets the number of permutations
config.nperms           = 10000;

% Sets rois to analyze in the statistical test
config.statrois = config.roi;

% Adds, if needed, the FieldTrip folder to the path.
addpath ( config.path.ft_path )
ft_defaults

% Loads the template.
template         = load ( config.template );
cortical_mask = ismember(template.grid.area,config.roi);

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


%% Load apexp and deal with missing values

% cumsum = 0;
% for iroi = 1 : numel(config.roi)
%     roi_mask = template.grid.area == config.roi(iroi);
%     fprintf('Roi %-2d | size %-2d | %s \n', iroi, sum(roi_mask), template.atlas.name{iroi})
%     cumsum = cumsum + sum(roi_mask);
% end

apexp_all = nan(numel ( files ), numel(cortical_mask));

% discard_rois = [];
discard_subjects = [];

% Goes though each file.
for findex = 1: numel ( files )

    % Loads the fooof data.
    fooofdata          = load ( fullfile ( files (findex).folder, files ( findex ).name ) );
    apexp = fooofdata.apexp_clean;

    switch config.dealnan
        case 'interpolate'
            for iroi = 1:numel(config.roi)

                roi_mask = template.grid.area == config.roi(iroi);
                apexp_roi = apexp(roi_mask);

                if all(isnan(apexp_roi))
                    warning('All nans in findex %-3d | roi %-2d | roi size %-2d',findex,iroi, sum(roi_mask));
                    discard_subjects = [discard_subjects findex];
                    % discard_rois = [discard_rois config.roi(iroi)];
                    continue
                end

                if any(isnan(apexp_roi))
                    % warning('Some nans in findex %d, roi %d',findex,iroi);
                    nanpos = isnan(apexp_roi);
                    mean_apexp = mean(apexp(roi_mask),'omitnan');
                    
                    idx_roi = find(roi_mask);
                    apexp(idx_roi(nanpos)) = mean_apexp;
                end

            end
        case 'omitsources'
        otherwise
            warning('\nAll subjects with nan values will be omited from the statistical analysis.\n')

    end

    apexp_all(findex,:) = apexp;

end
discard_subjects = unique(discard_subjects);
% discard_rois = unique(discard_rois);
% config.statrois = config.roi(~ismember(config.roi, discard_rois));

%% Create data structure for cbpt
data             = cell ( numel ( files ), 1 );
data_struct = struct();
for findex = 1: numel ( files )
    % Create data structure for cbpt
    data_struct.subject = extractBefore(files ( findex ).name, '_');

    sources          = [];
    sources.dim      = template.grid.dim;
    sources.pos      = template.grid.pos;
    sources.inside   = ismember ( template.grid.area, config.statrois );
    sources.dimord   = 'pos';
    sources.unit     = template.grid.unit;
    sources.apexp_clean = apexp_all(findex,:);
    data_struct.sources  = sources;

    % Stores the data.
    data { findex }  = data_struct;
end

% Concatenates all the data.
data             = cat ( 1, data {:} );


% cumsum = 0;
% for iroi = 1 : numel(config.statrois)
%     roi_mask = template.grid.area == config.statrois(iroi);
%     fprintf('Roi %-2d | size %-2d | %s \n', iroi, sum(roi_mask), template.atlas.name{iroi})
%     cumsum = cumsum + sum(roi_mask);
% end
% statrois_mask = ismember(template.grid.area,config.statrois);
% apexp_stat = apexp_all(:,statrois_mask);
% find(any(isnan(apexp_stat),2));

%% Generates the design matrix.
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

%%

idx = find(cortical_mask)';

for iSource=1:10
    figure
    hold on
    r = randi(1210);
    hLegend = gobjects(numel(config.group),1);

    for gindex = 1: numel ( config.group )
        hits             = ismember ( participants.group_merged, config.group{gindex} );
        x = participants.age(hits);
        y = apexp_all(hits, idx(r));

        hScatter = scatter(x, y, 'filled');
        scatterColor = hScatter.CData;
        hLegend(gindex) = hScatter;

        mdl = fitlm(x, y);
        slope = mdl.Coefficients.Estimate(2);
        intercept = mdl.Coefficients.Estimate(1);
        % Regression line
        xfit = linspace(min(x), max(x), 100);
        yfit = intercept + slope * xfit;

        plot(xfit, yfit, 'LineWidth', 2,'Color', scatterColor);

    end
    legend(hLegend, config.group);

end
%% Calculates the CBPT.
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
cfg.ivar             = [ 1 2 ]; % the covariate is included as independent variable
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

filename = ['stats_apexp_cbpt_' group_str '_new.mat'];

save ( '-v6', fullfile(config.path.stats, filename), '-struct', 'statdata' )