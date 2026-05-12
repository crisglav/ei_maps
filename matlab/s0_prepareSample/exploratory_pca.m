clear
clc

rng(42)

%% -----------------
% Load and select participants
% -----------------

participants_path = "C:\Users\Cristina\megtusalen\L1\data\participants\participants_megtusalen_corrected_diagcog.xlsx";
participants = readtable(participants_path);

participants_ei_path = "C:\Users\Cristina\repos\ei_maps\data\participants_sample_new.xlsx";
participants_ei = readtable(participants_ei_path);

% Keep only included participants
participants = join( ...
    participants, ...
    participants_ei(:, {'participant_id','included'}), ...
    'Keys', 'participant_id');

participants = participants(participants.included == true, :);

%% -----------------
% Harmonize education level
% -----------------

participants.edu_level = nan(height(participants), 1);

mask = strcmp(participants.project_id, "UMEC");

participants.edu_level(mask & ismember(participants.edu_level_umec, 1)) = 1;
participants.edu_level(mask & ismember(participants.edu_level_umec, [2 3])) = 2;
participants.edu_level(mask & ismember(participants.edu_level_umec, 4)) = 3;
participants.edu_level(mask & ismember(participants.edu_level_umec, 5)) = 4;

mask = strcmp(participants.project_id, "FAM");

participants.edu_level(mask & ismember(participants.edu_level_fam, 1)) = 1;
participants.edu_level(mask & ismember(participants.edu_level_fam, [2 3])) = 2;
participants.edu_level(mask & ismember(participants.edu_level_fam, 4)) = 3;
participants.edu_level(mask & ismember(participants.edu_level_fam, 5)) = 4;

mask = strcmp(participants.project_id, "NEMOS");

participants.edu_level(mask & ismember(participants.edu_level_nemos, 1)) = 1;
participants.edu_level(mask & ismember(participants.edu_level_nemos, 2)) = 2;
participants.edu_level(mask & ismember(participants.edu_level_nemos, [3 4])) = 3;
participants.edu_level(mask & ismember(participants.edu_level_nemos, 5)) = 4;

%% -----------------
% Harmonize occupation
% -----------------

participants.occupation = nan(height(participants), 1);

mask = strcmp(participants.project_id, "UMEC");

participants.occupation(mask & ismember(participants.occupation_umec, 0)) = 1;
participants.occupation(mask & ismember(participants.occupation_umec, [1 2])) = 2;
participants.occupation(mask & ismember(participants.occupation_umec, 3)) = 3;
participants.occupation(mask & ismember(participants.occupation_umec, 4)) = 4;

mask = strcmp(participants.project_id, "FAM");

participants.occupation(mask & ismember(participants.occupation_fam, 0)) = 1;
participants.occupation(mask & ismember(participants.occupation_fam, [1 2])) = 2;
participants.occupation(mask & ismember(participants.occupation_fam, 3)) = 3;
participants.occupation(mask & ismember(participants.occupation_fam, 4)) = 4;

mask = strcmp(participants.project_id, "NEMOS");

participants.occupation(mask & ismember(participants.occupation_nemos, [1 2])) = 1;
participants.occupation(mask & ismember(participants.occupation_nemos, 3)) = 2;
participants.occupation(mask & ismember(participants.occupation_nemos, 4)) = 3;
participants.occupation(mask & ismember(participants.occupation_nemos, 5)) = 4;

%% -----------------
% Select variables common to all datasets
% -----------------

keep_cols = { ...
    'age','sex','edu_level','occupation', ...
    'DST_forward', 'DST_backward', 'GDS_15', ...
    'LM_imm_units', 'LM_del_units', 'LM_imm_them', 'LM_del_them', 'mmse_extended', ...
    'PFT', 'SFT', ...
    'TMT_A_time', 'TMT_B_time', ...
    'APOE', 'ACT', 'BACE1', 'BDNF', 'CHRNA7', 'CLU', 'COMT', 'CR1', 'ERBB4', 'NRG1', 'PICALM' ...
};

data = participants(:, keep_cols);

% Count number of NaN values
nan_counts = varfun(@(x) sum(ismissing(x)), data);
disp(nan_counts)


%% -----------------
% Neuropsychological profile
% -----------------

neuropsycho_vars = { 
    'DST_forward', 'DST_backward', 'GDS_15', ...
    'LM_imm_units', 'LM_del_units', 'LM_imm_them', 'LM_del_them', 'mmse_extended', ...
    'PFT', 'SFT', ...
    'TMT_A_time', 'TMT_B_time' ...
};

x = data(:, neuropsycho_vars);
x = table2array(x);

% Remove participants with NaNs
[x,tf] = rmmissing(x);
[n,p] = size(x);

% Zscore data
xz = zscore(x);

% Covariance matrix
cov = xz'*xz / (n-1);
e = eig(cov);

% SVD
[u,s,v] = svd(xz); % xz = u*s*v'

% PCA
[coeff, score, latent, tsquared, explained, mu] = pca(xz);


% Checks

latent_ = sort(e,'descend'); % Variance
disp([latent_ latent])

explained_ = latent/sum(latent)*100; % Explained variance
disp([explained_ explained_])

coeff_ = v; % PCA coefficients

score_ = xz*v;
% score_ = u*s;

% Reconstructed data
xorig = score*coeff';
% v*v' = eye(p)
xorig = xz*v*v';

%%

% Biplot
figure
h = biplot(coeff(:,1:2),'scores',score(:,1:2),'VarLabels',neuropsycho_vars);
score_h = findobj(gca, 'Tag', 'obsmarker');
score_h = flipud(score_h);

coeff_h = findobj(gca, 'Tag', 'varline');
set(coeff_h, 'Color', [0.8 0.8 0.8], 'LineWidth', 1);


% Color by diagnosis
% diag = categorical(participants.diagnosis(~tf));
% diag_cat = {'HC','FH','SCD','MCI','AD'};
% cl = [
%     0.20 0.60 0.20   % green
%     0.55 0.80 0.55   % light green
%     1.00 0.85 0.00   % yellow
%     0.90 0.55 0.15   % orange
%     0.80 0.20 0.20   % red
% ];

diag = categorical(participants.group(~tf));
diag_cat = {'FHneg','FHpos','SCDneg','MCIneg','SCDpos','MCIa','MCIm','AD'};
cl = [
    0.15 0.55 0.25   % dark green
    0.35 0.75 0.45   % light green
    0.45 0.25 0.70   % dark purple
    0.70 0.40 0.80   % pink
    0.90 0.75 0.10   % yellow
    0.90 0.50 0.10   % orange
    0.90 0.50 0.10   % orange
    0.80 0.25 0.25   % red
];
% alpha = [0 0 0 1 0 1 1 1]; % mci vs mcineg
% alpha = [0 0 1 0 1 0 0 0]; % scd vs scdneg
% alpha = [0 0 1 1 0 0 0 0]; % scdneg vs mcineg
alpha = [1 1 0 0 0 0 0 0]; % fhneg vs fhpos
% alpha = [1 1 1 1 1 1 1 1]; % all

legend_h = gobjects(numel(diag_cat),1);
for i=1:numel(diag_cat)
    mask = diag == diag_cat{i};
    set(score_h(mask), 'Color', cl(i,:),'MarkerSize', 10);
    if alpha(i) == 0
        set(score_h(mask), 'Visible', 'off')
    end
    idx = find(mask, 1, 'first');
    legend_h(i) = score_h(idx);
end

legend(legend_h, diag_cat, 'Location', 'best')

% figure
% hold on
% 
% % Plot scores
% % scatter(score(:,1), score(:,2), 15, 'r', 'filled')
% 
% % Scaling factor similar to biplot
% scale = max(abs(score(:,1:2)), [], 'all');
% scale= 1;
% 
% % Plot coefficient vectors
% quiver( ...
%     zeros(size(coeff,1),1), ...
%     zeros(size(coeff,1),1), ...
%     coeff(:,1) * scale, ...
%     coeff(:,2) * scale, ...
%     0, ...
%     'k', ...
%     'LineWidth', 1.5)
% 
% % Variable labels
% text( ...
%     coeff(:,1) * scale, ...
%     coeff(:,2) * scale, ...
%     neuropsycho_vars, ...
%     'FontSize', 10)
% 
% xlabel('PC1')
% ylabel('PC2')
% 
% axis equal
% grid on
% box off

figfolder = 'C:\Users\Cristina\repos\ei_maps\figs\pca';
mkdir(figfolder);
saveas(gcf, fullfile(figfolder, 'pca_biplot_fam.svg'))