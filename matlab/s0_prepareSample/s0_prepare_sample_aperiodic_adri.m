%%  s1_prepare_sample

% v1.0 03/23


clear all
close all


%% Parameters

name2save           = 'Aperiodic_tesis_all_v1';


%%  Load main BBDD

[~, ~, sample]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'sample');
sample(cell2mat(cellfun(@(x) strcmp(x,'nan'), sample, 'UniformOutput',false))) = {nan};
sample(cell2mat(cellfun(@(x) strcmp(x,'NaN'), sample, 'UniformOutput',false))) = {nan};

[~, ~, neuropsico]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'neuropsico');
neuropsico(cell2mat(cellfun(@(x) strcmp(x,'nan'), neuropsico, 'UniformOutput',false))) = {nan};
neuropsico(cell2mat(cellfun(@(x) strcmp(x,'NaN'), neuropsico, 'UniformOutput',false))) = {nan};

[~, ~, meg]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'megdata');
meg(cell2mat(cellfun(@(x) strcmp(x,'nan'), meg, 'UniformOutput',false))) = {nan};
meg(cell2mat(cellfun(@(x) strcmp(x,'NaN'), meg, 'UniformOutput',false))) = {nan};

[~, ~, genes]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'genes');
genes(cell2mat(cellfun(@(x) strcmp(x,'nan'), genes, 'UniformOutput',false))) = {nan};
genes(cell2mat(cellfun(@(x) strcmp(x,'NaN'), genes, 'UniformOutput',false))) = {nan};

[~, ~, dtis]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'dtis');
dtis(cell2mat(cellfun(@(x) strcmp(x,'nan'), dtis, 'UniformOutput',false))) = {nan};
dtis(cell2mat(cellfun(@(x) strcmp(x,'NaN'), dtis, 'UniformOutput',false))) = {nan};

[~, ~, vols_aseg]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'vols_aseg_lobes');
vols_aseg(cell2mat(cellfun(@(x) strcmp(x,'nan'), vols_aseg, 'UniformOutput',false))) = {nan};
vols_aseg(cell2mat(cellfun(@(x) strcmp(x,'NaN'), vols_aseg, 'UniformOutput',false))) = {nan};

[~, ~, vols_aparc]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'vols_aparc');
vols_aparc(cell2mat(cellfun(@(x) strcmp(x,'nan'), vols_aparc, 'UniformOutput',false))) = {nan};
vols_aparc(cell2mat(cellfun(@(x) strcmp(x,'NaN'), vols_aparc, 'UniformOutput',false))) = {nan};

[~, ~, vols_exvivo]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'vols_exvivo');
vols_exvivo(cell2mat(cellfun(@(x) strcmp(x,'nan'), vols_exvivo, 'UniformOutput',false))) = {nan};
vols_exvivo(cell2mat(cellfun(@(x) strcmp(x,'NaN'), vols_exvivo, 'UniformOutput',false))) = {nan};

[~, ~, vols_wm]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'vols_wm');
vols_wm(cell2mat(cellfun(@(x) strcmp(x,'nan'), vols_wm, 'UniformOutput',false))) = {nan};
vols_wm(cell2mat(cellfun(@(x) strcmp(x,'NaN'), vols_wm, 'UniformOutput',false))) = {nan};

[~, ~, wmh]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'wmh');
wmh(cell2mat(cellfun(@(x) strcmp(x,'nan'), wmh, 'UniformOutput',false))) = {nan};
wmh(cell2mat(cellfun(@(x) strcmp(x,'NaN'), wmh, 'UniformOutput',false))) = {nan};

[~, ~, mrirep]   = xlsread('../../../../Base de datos/megtusalen_tesis_adri_v2025.xlsx', 'mri reports');


%%  Vals to play
% codes_init      = sample(2:end, ismember(sample(1, :), 'id_meg'));
age             = cell2mat(sample(2:end, ismember(sample(1, :), 'age')));
% sex             = cell2mat(sample(2:end, ismember(sample(1, :), 'sex')));
diag_tri        = cell2mat(sample(2:end, ismember(sample(1, :), 'diag_mac')));

% 1 = Control 
% 2 = MCI
% 3 = AD

% diag_expandido  = cell2mat(sample(2:end, ismember(sample(1, :), 'diag')));

%  1 = Control (de MCI)
%  2 = control con QSM
%  3 = DCLa (solo amnesia)
%  4 = DCLm (multidominio con amnesia)
%  5 = DCLu (multidominio sin amnesia)
%  6 = AD
%  7 = control con antecedentes de AD
%  8 = control sin QSM
%  9 = control sin antecedentes de AD
% 10 = No definido

existfc         = ~isnan(cell2mat(meg(2:end, ismember(meg(1, :), 'exist_fc_sources'))));
existpow        = ~isnan(cell2mat(meg(2:end, ismember(meg(1, :), 'exist_pow_sources'))));

%   MRI REPORTS
mri_diag            = mrirep(2:end, ismember(mrirep(1, :), 'diagnostic'));
mri_class           = mrirep(2:end, ismember(mrirep(1, :), 'classification'));
mri_ictus           = mrirep(2:end, ismember(mrirep(1, :), '1 large lesion'));

mrirep_ictus_ok     = contains(mri_ictus, 'nan');

mrirep_words_out    = {'tumor'};%{'tumor', 'CV'};
mrirep_ok           = ~contains(mri_diag, mrirep_words_out) & ~contains(mri_class, mrirep_words_out);
% mrirep_superok      = find(contains(mri_diag, 'no alterations') & contains(mri_class, 'no alterations'));


%   Sujetos fuera por problemas varios
codes           = sample(2:end, ismember(sample(1, :), 'id_meg'));



%%   Subjects available
subs_okcn           = diag_tri == 1 & age >= 50 & existfc & existpow & mrirep_ok & mrirep_ictus_ok;
subs_okmci          = diag_tri == 2 & age >= 50 & existfc & existpow & mrirep_ok & mrirep_ictus_ok;
subs_okad           = diag_tri == 3 & age >= 50 & existfc & existpow & mrirep_ok & mrirep_ictus_ok;

subs_ok             = subs_okcn | subs_okmci | subs_okad;

clear diag age wmh_ok vols_ok dtis_ok existpow existfc scok inmediatas_ok mrirep_words_out
clear mrirep_ok mrirep_ictus_ok mri_diag mri_class mri_ictus mrirep mmse sex spectra diag_tri


%%  Ajustamos

sample_vals             = cell2mat(sample(2:end, 3:end));
sample_vals             = sample_vals(subs_ok, :);

neuropsico_vals         = cell2mat(neuropsico(2:end, 3:end));
neuropsico_vals         = neuropsico_vals(subs_ok, :);

meg_vals                = cell2mat(meg(2:end, 3:end));
meg_vals                = meg_vals(subs_ok, :);

genes_vals              = cell2mat(genes(2:end, 3));
genes_vals              = genes_vals(subs_ok, :);

dtis_vals               = cell2mat(dtis(2:end, 3:end));
dtis_vals               = dtis_vals(subs_ok, :);

vols_aseg_vals          = cell2mat(vols_aseg(2:end, 3:end));
vols_aseg_vals          = vols_aseg_vals(subs_ok, :);

vols_aparc_vals         = cell2mat(vols_aparc(2:end, 3:end));
vols_aparc_vals         = vols_aparc_vals(subs_ok, :);

vols_exvivo_vals        = cell2mat(vols_exvivo(2:end, 3:end));
vols_exvivo_vals        = vols_exvivo_vals(subs_ok, :);

vols_wm_vals            = cell2mat(vols_wm(2:end, 3:end));
vols_wm_vals            = vols_wm_vals(subs_ok, :);

wmh_vals                = cell2mat(wmh(2:end, 3:end-1));
wmh_vals                = wmh_vals(subs_ok, :);

codes                   = sample(2:end, 1:2);
codes                   = codes(subs_ok, :);


%%  Prepare BBDD

bbdd                    = [];
bbdd.name               = name2save;
bbdd.subcodes           = codes(:, 2);
bbdd.sample_names       = sample(1, 3:end)';
bbdd.sample_vals        = sample_vals;
bbdd.neuropsico_names   = neuropsico(1, 3:end)';
bbdd.neuropsico_vals    = neuropsico_vals;
bbdd.meg_names          = meg(1, 3:end)';
bbdd.meg_vals           = meg_vals;
bbdd.genes_names        = genes(1, 3)';
bbdd.genes_vals         = genes_vals;
bbdd.dtis_names         = dtis(1, 3:end)';
bbdd.dtis_vals          = dtis_vals;
bbdd.vols_aseg_names    = vols_aseg(1, 3:end)';
bbdd.vols_aseg_vals     = vols_aseg_vals;
bbdd.vols_aparc_names   = vols_aparc(1, 3:end)';
bbdd.vols_aparc_vals    = vols_aparc_vals;
bbdd.vols_exvivo_names  = vols_exvivo(1, 3:end)';
bbdd.vols_exvivo_vals   = vols_exvivo_vals;
bbdd.vols_wm_names      = vols_wm(1, 3:end)';
bbdd.vols_wm_vals       = vols_wm_vals;
bbdd.wmh_names          = wmh(1, 3:end-1)';
bbdd.wmh_vals           = wmh_vals;
bbdd.update             = datestr(now);


clear wmh mrirep sample dtis vols dtis_vals vols_vals genes genes_names fcok
clear sample_vals subs_ok wmh_vals genes_vals mrirep_names mrirep_vals codes
clear codes_init codesok fcok mmse mri_class mri_diag mri_ictus mrirep_ictus_ok
clear mrirep_ok mrirep_words_out scok spectra subs_okcn subs_okmci subsout
clear wmh_names diag_tri inmediatas_ok sex meg_vals vols_aseg vols_wm 
clear vols_aseg_vals vols_wm_vals meg neuropsico neuropsico_vals vols_aparc
clear vols_aparc_vals vols_exvivo vols_exvivo_vals subs_okad



%%  Selecionamos la parte que nos interesa
sample_in                       = 1:9;
neuropsico_in                   = [5 6 14 16 36 40:43];
meg_in                          = 1:6;
genes_in                        = 1;
dti_in                          = 1:27;
vols_aseg_in                    = [1 2 4:11 16:19 22 23 33:38 58:77]; 
vols_aparc_in                   = [2 106 209];
vols_exvivo_in                  = [13 14 27 29 41 42 55 56 85:88];
vols_wm_in                      = [1:3 5:37 39:71];
wmh_in                          = [5 7 9 22 23];

sample                          = [];
sample.subcodes                 = bbdd.subcodes;
sample.scores                   = cat(2, bbdd.sample_vals(:, sample_in), bbdd.neuropsico_vals(:, neuropsico_in), bbdd.meg_vals(:, meg_in), bbdd.genes_vals(:, genes_in), bbdd.dtis_vals(:, dti_in), bbdd.vols_aseg_vals(:, vols_aseg_in), bbdd.vols_aparc_vals(:, vols_aparc_in), bbdd.vols_exvivo_vals(:, vols_exvivo_in), bbdd.vols_wm_vals(:, vols_wm_in), bbdd.wmh_vals(:, wmh_in));
sample.scoresnames              = cat(1, bbdd.sample_names(sample_in), bbdd.neuropsico_names(neuropsico_in), bbdd.meg_names(meg_in), bbdd.genes_names(genes_in), bbdd.dtis_names(dti_in), bbdd.vols_aseg_names(vols_aseg_in), bbdd.vols_aparc_names(vols_aparc_in), bbdd.vols_exvivo_names(vols_exvivo_in), bbdd.vols_wm_names(vols_wm_in), bbdd.wmh_names(wmh_in));


clear vols_aseg_in neuro_in wmh wmh_names dti_in idx2round vols_wm_in vols_aparc_in vols_exvivo_in wmh_in meg_in sample_in neuropsico_in genes_in


%   Creamos bbdd completa dentro de otra variable
sample_in                       = 1:17;
neuropsico_in                   = 1:43;
meg_in                          = 1:6;
genes_in                        = 1;
dti_in                          = 1:54;
vols_aseg_in                    = 1:127; 
vols_aparc_in                   = 1:209;
vols_exvivo_in                  = 1:88;
vols_wm_in                      = 1:71;
wmh_in                          = 1:28;

sample.wholebbdd.sample_scores      = cat(2, bbdd.sample_vals(:, sample_in));
sample.wholebbdd.sample_names       = cat(1, bbdd.sample_names(sample_in));
sample.wholebbdd.neuropsico_scores  = cat(2, bbdd.neuropsico_vals(:, neuropsico_in));
sample.wholebbdd.neuropsico_names   = cat(1, bbdd.neuropsico_names(neuropsico_in));
sample.wholebbdd.meg_scores         = cat(2, bbdd.meg_vals(:, meg_in));
sample.wholebbdd.meg_names          = cat(1, bbdd.meg_names(meg_in));
sample.wholebbdd.genes_scores       = cat(2, bbdd.genes_vals(:, genes_in));
sample.wholebbdd.genes_names        = cat(1, bbdd.genes_names(genes_in));
sample.wholebbdd.dti_scores         = cat(2, bbdd.dtis_vals(:, dti_in));
sample.wholebbdd.dti_names          = cat(1, bbdd.dtis_names(dti_in));
sample.wholebbdd.vols_aseg_scores   = cat(2, bbdd.vols_aseg_vals(:, vols_aseg_in));
sample.wholebbdd.vols_aseg_names    = cat(1, bbdd.vols_aseg_names(vols_aseg_in));
sample.wholebbdd.vols_aparc_scores  = cat(2, bbdd.vols_aparc_vals(:, vols_aparc_in));
sample.wholebbdd.vols_aparc_names   = cat(1, bbdd.vols_aparc_names(vols_aparc_in));
sample.wholebbdd.vols_exvivo_scores = cat(2, bbdd.vols_exvivo_vals(:, vols_exvivo_in));
sample.wholebbdd.vols_exvivo_names  = cat(1, bbdd.vols_exvivo_names(vols_exvivo_in));
sample.wholebbdd.vols_wm_scores     = cat(2, bbdd.vols_wm_vals(:, vols_wm_in));
sample.wholebbdd.vols_wm_names      = cat(1, bbdd.vols_wm_names(vols_wm_in));
sample.wholebbdd.wmh_scores         = cat(2, bbdd.wmh_vals(:, wmh_in));
sample.wholebbdd.wmh_names          = cat(1, bbdd.wmh_names(wmh_in));


clear vols_aseg_in neuro_in wmh wmh_names dti_in idx2round vols_wm_in vols_aparc_in vols_exvivo_in wmh_in meg_in sample_in neuropsico_in genes_in


%   Save the bbdd
sample.update                   = datestr(now);

save( [ name2save '_' num2str(numel(bbdd.subcodes)) 's'], 'sample' )


%% Prepare excel

%   Sample
database                    = cell(numel(bbdd.subcodes) + 1, numel(sample.scoresnames) + 1);
database{1, 1}              = 'id_proj';
database(2:end, 1)          = bbdd.subcodes;
database(1, 2:end)          = sample.scoresnames;
database(2:end, 2:end)      = num2cell(sample.scores);
xlswrite([ name2save '_' num2str(numel(bbdd.subcodes)) 's'], database, 'sample');