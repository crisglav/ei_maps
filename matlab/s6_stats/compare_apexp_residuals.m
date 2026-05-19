clc
clear
close all

% Adds the functions and templates to the path.
addpath ( fullfile ( '..', 'functions') );
addpath ( fullfile ( '..', 'templates') );
addpath ('functions');

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );


% Sets the paths.
config.path.project_root = 'C:\Users\Cristina\megtusalen';
config.path.fooofL1      = fullfile( config.path.project_root, 'L1', 'data', 'sources', 'fooof_py');
config.path.fooofL2      = fullfile(  config.path.project_root, 'L2', 'data', 'sources', 'fooof_py');
config.path.patt         = '*_sources.mat';
config.path.sample       = fullfile( '..', '..', 'data', 'participants_real.xlsx');
config.path.stats        = fullfile( '..','..','results', 'stats', 'apexp_residuals');
config.path.ft_path      = 'C:\Users\Cristina\repos\fieldtrip';


% Defines the groups to compare.
% config.group = {'FHneg', 'FHpos'};
config.group = {'SCDneg', 'SCDpos'};
% config.group = {'MCIneg', 'MCI', 'AD'};
% config.group = {'SCDneg', 'SCDpos', 'MCIneg', 'MCI', 'AD'};

% Defines the template.
config.template        = 'template_AAL';
config.roi = [1:40, 43:70, 79:90]'; % Only cortical sources

% % Sets the options for the statsitics.
if numel(config.group) > 2
    % ANOVA
    config.test            = 'anova';
    config.statistic       = 'myft_statfun_anova';
    config.tail            = 1;
    config.clustertail     = 1;
    config.correcttail     = 'no';
else
    % T-TEST
    config.test            = 'ttest';
    config.statistic       = 'ft_statfun_indepsamplesT';
    config.tail            = 0;
    config.clustertail     = 0;
    config.correcttail     = 'prob';
end

config.metric          = 'apexp';
config.alpha           = 0.05;

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

% Convert to categorical
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

%% Load aperiodic exponent data and deal with nan values
% Impute apexp to rois which are missing some apexp value. Fill missing values for that roi with
% the mean of that roi. If all values of a roi
% are missing the participant will be discarded from the statistical
% analysis.

% List all rois and their size
% cumsum = 0;
% for iroi = 1 : numel(config.roi)
%     roi_mask = template.grid.area == config.roi(iroi);
%     fprintf('Roi %-2d | size %-2d | %s \n', iroi, sum(roi_mask), template.atlas.name{iroi})
%     cumsum = cumsum + sum(roi_mask);
% end

apexp_all = nan(numel ( files ), numel(cortical_mask));

discard_idx = [];
discard_subjects = {};

% Goes though each file.
for findex = 1: numel ( files )

    % Loads the fooof data.
    fooofdata          = load ( fullfile ( files (findex).folder, files ( findex ).name ) );
    apexp = fooofdata.apexp_clean;

    for iroi = 1:numel(config.roi)

        roi_mask = template.grid.area == config.roi(iroi);
        apexp_roi = apexp(roi_mask);

        % Discard subjects who are missing a whole roi
        if all(isnan(apexp_roi))
            % warning('All nans in findex %-3d | roi %-2d | roi size %-2d',findex, iroi, sum(roi_mask));
            discard_idx = [discard_idx findex];
            discard_subjects{end+1} = fooofdata.subject;
            break
        end

        % For missing values in a roi impute the mean of apex in that roi
        if any(isnan(apexp_roi))
            % Check the percentage of sources of the roi that are
            % missing. If more than 50%, do not impute value, but skip
            % subject.
            nanpos = isnan(apexp_roi);
            pernan = (sum(nanpos) / sum(roi_mask)) * 100; 
            % warning('findex %-3d | roi %-2d | roi size %-2d | percentage nan %-5.1f',findex, iroi, sum(roi_mask), pernan);

            if pernan > 50
                % warning('Participant will be discarded: findex %-3d | roi %-2d | roi size %-2d | percentage nan %-5.1f',findex, iroi, sum(roi_mask), pernan);
                discard_idx = [discard_idx findex];
                discard_subjects{end+1} = fooofdata.subject;
                break
            else
                mean_apexp = mean(apexp(roi_mask),'omitnan');
                idx_roi = find(roi_mask);
                apexp(idx_roi(nanpos)) = mean_apexp;
            end
        end

    end

    apexp_all(findex,:) = apexp;

end
discard_idx = unique(discard_idx);
discard_subjects = unique(string(discard_subjects));
subject_mask = ~ismember(string(participants.participant_id), discard_subjects);

% Discard subjects
participants = participants(subject_mask,:);

%% Generates the design matrix.
design           = nan ( 1, height ( participants ) );

% Fills the design matrix.
for gindex = 1: numel ( config.group )
    hits             = ismember ( participants.group_merged, config.group{gindex} );
    design ( hits )  = gindex;
end

% Lists only the valid data.
valid            = all ( isfinite ( design ), 1 );

%% Fit a linear regression at each source to remove the influence of age
age = participants.age;
apexp_all = apexp_all(subject_mask,:);
apexp_res = nan(size(apexp_all));
source_idx = find(cortical_mask);

% Regress out age separately for each group
for iSource = 1:numel(source_idx)

    col = source_idx(iSource);
    
    for gindex = 1: numel ( config.group )

        hits             = ismember ( participants.group_merged, config.group{gindex} );
        model_apexp = fitlm(age(hits),apexp_all(hits,col));
        apexp_res(hits,col) = model_apexp.Residuals.Raw;    

    end

end

% Regress out age jointly for participants included in any of the three groups
for iSource = 1:numel(source_idx)

    col = source_idx(iSource);
    model_apexp = fitlm(age(valid), apexp_all(valid, col));
    apexp_res(valid, col) = model_apexp.Residuals.Raw;

end

% Regress out age for the whole sample
% for iSource = 1:numel(source_idx)
% 
%     col = source_idx(iSource);
%     model_apexp = fitlm(age, apexp_all(:, col));
%     apexp_res(:, col) = model_apexp.Residuals.Raw;
% 
% end

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
    sources.apexp_res = apexp_res(findex,:);
    data_struct.sources  = sources;

    % Stores the data.
    data { findex }  = data_struct;
end

% Concatenates all the data.
data             = cat ( 1, data {:} );



%% CBPT

% Calculates the CBPT.
cfg                  = [];
cfg.parameter        = 'apexp_res';
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
cfg.ivar             = 1;
cfg.randomseed       = 10;

% Sets the number of permutations
config.nperms           = 10000;

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

filename = ['stats_apexp_res_cbpt_' group_str '_valid.mat'];

save ( '-v6', fullfile(config.path.stats, filename), '-struct', 'statdata' )
