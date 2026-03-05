%% Select sample from Megtusalen dadataset
% 
% This script selects the sample to be used at the ei_maps project based on
% the inclusion and exclusion criteria defined below.
%
% Cristina Gil Avila, 26/03/2025, C3N

% The diagcog score was created to assess which participants labeled 
% healthy passed the neuropsychological scores. For more information on how
% this variable was created, check the script
% s1_processing_neurohealthy_MEGTUSALEN_cristina.m

clear all;
close all;
clc;
%% Load megtusalen excel data with diagcog scores.
excel_file = '../../data/supermegtusalen_global_v2026_diagcog.xlsx';

% Information about MEG Data
megtusalen_meg = readtable(excel_file,'Sheet','megdata',ReadVariableNames=true, VariableNamesRange='A1:I1', DataRange="A2:I761");

% Information about demographic data
megtusalen_sample = readtable(excel_file,'Sheet','sample');

% Clinical information based on MRI (existance of tumors, hemorrages, etc.)
megtusalen_mri = readtable(excel_file,'Sheet','mri_reports');

% Make sure that participants' labels are the same in all the excel sheets
mask1 = cellfun(@isequal, megtusalen_meg.id_meg, megtusalen_sample.id_meg);
mask2 = cellfun(@isequal, megtusalen_meg.id_meg, megtusalen_mri.id_meg);
if ~all(mask1 & mask2)
    warning('The order of participants labels does not match between excel sheets.');
end
clear mask1 mask2

% Make sure that all recordings belong to baseline (no longitudinal data) 
id_meg = megtusalen_meg.id_meg;
id_1 = cellfun(@(x) numel(x) >= 2 && x(2) == '1', id_meg);
if ~all(id_1)
    warning('Check for longitudinal recordings.\n')
end

n = height(megtusalen_sample);

%% Inclusion and exclusion criteria (Cristina)

% 1. Participant must have a group label
% 2. Participant must have basic demographic data (age, gender)
% 3. Participant must have an ok MRI report (no tumors, no ictus)
% 4. Healthy participants must have a MMSE report >= 26
% 5. For healthy controls, participant must not have a negative
% neuropsychological assessment.
% 6. Participant must have a raw MEG recording (sensor data)
% (7). Participant must have power spectrum in source space

% 1. Participants with a defined group label (N = 730) Excluded N = 30
diag = megtusalen_sample.diag;
mask_diag = ~isnan(diag);
fprintf('\n\n%d participants with diagnostic data.\n', sum(mask_diag));

% 2. Participants with demographic data
mask_age = ~isnan(megtusalen_sample.age); % N = 717
mask_gender = ~isnan(megtusalen_sample.sex); % N = 723
fprintf('\t%d participants with age data.\n', sum(mask_age));
fprintf('\t%d participants with sex data.\n', sum(mask_gender));
fprintf('%d participants with diagnostic and demographic data.\n', sum(mask_diag & mask_age & mask_gender));

% Participants with MRI data
mask_mri = megtusalen_mri.ExisteT1 | megtusalen_mri.ExisteFlair;
fprintf('%d participants with MRI data.\n', sum(mask_diag & mask_age & mask_gender & mask_mri));

% Participants with MEG data
mask_sens =  megtusalen_meg.missing_sens == 0;
% mask_sens =  ~isnan(megtusalen_meg.exist_sens);
fprintf('%d participants with MEG data.\n', sum(mask_diag & mask_age & mask_gender & mask_sens));

% Participants with GDS > 14
mask_gds = megtusalen_sample.GDS_depres > 14;
fprintf('%d participants with diagnostic and demographic data and GDS <= 14.\n', sum(mask_diag & mask_age & mask_gender & ~mask_gds));

% Participants with MRI
mask_mri = megtusalen_mri.ExisteT1 | megtusalen_mri.ExisteFlair;
fprintf('\t%d participants with MRI.\n', sum(mask_diag & mask_age & mask_gender & ~mask_gds & mask_mri));

% Participants that DO NOT have a diagnosis or classification of 'tumor' based on
% their MRI. (N = 745) Excluded N = 15
mri_diag = megtusalen_mri.diagnostic;
mri_class = megtusalen_mri.classification;
diag_tumor = contains(mri_diag,'tumor');
class_tumor = contains(mri_class,'tumor');
mask_notumor = ~or(diag_tumor,class_tumor);
fprintf('\t%d participants with diagnostic and demographic data that do not have a tumor.\n', sum(mask_diag & mask_age & mask_gender & ~mask_gds & mask_notumor));

% Participants that DO NOT have a large lession (hemorragic, ischemic, etc.) in
% their MRI. (N = 742) Excluded N = 18
mri_lession = megtusalen_mri.x1LargeLesion;
mask_nolession = strcmp(mri_lession,'nan');
fprintf('\t%d participants with diagnostic and demographic data that do not have a large lession.\n', sum(mask_diag & mask_age & mask_gender & ~mask_gds & mask_nolession));

% 3. Participants without tumors or ictus (N = 727) Excluded N = 33
mask_mriok = mask_notumor & mask_nolession;
fprintf('%d participants with diagnostic and demographic data that do not have bad MRI.\n', sum(mask_diag & mask_age & mask_gender & ~mask_gds & mask_mriok));

% 4. Healthy participants must have an (adjusted) MMSE report >= 26
cn  = [1, 8, 9];
mask_cn  = sum(diag == cn ,2); % N = 520
mask_mmse = ~(mask_cn & megtusalen_sample.mmse_extended >=26);
% mask_mmse = ~(mask_cn & megtusalen_sample.mmse_ok == 0);
fprintf('\t %d participants with MMSE.\n', sum(mask_diag & mask_age & mask_gender & ~mask_gds & mask_mriok & mask_mmse));
fprintf('%d participants with diagnostic and demographic data that do not have bad MRI, nor MMSE < 26 being healhty.\n', sum(mask_diag & mask_age & mask_gender & ~mask_gds & mask_mriok & mask_mmse));
fprintf('\t%d participants with extended MMSE.\n', sum(mask_diag & mask_age & mask_gender & mask_mriok & (~isnan(megtusalen_sample.mmse_extended))));
fprintf('\t%d participants with adjusted MMSE.\n', sum(mask_diag & mask_age & mask_gender & mask_mriok & (~isnan(megtusalen_sample.mmse_adj))));

% 5. Healthy participants without a negative neuropsychological assessment
mask_diagcog = ~(mask_cn & megtusalen_sample.diagcog < 2);
% mask_diagcog = ~(mask_cn & megtusalen_sample.diagcog == 0);
fprintf(['%d participants with diagnostic and demographic data that do not have bad MRI, nor MMSE < 26 or diagcog ' ...
    '= 0 being healthy.\n'], sum(mask_diag & mask_age & mask_gender & ~mask_gds & mask_mriok & mask_mmse & mask_diagcog));

% 6. Participants with an MEG recording (sensor data) according the excel file (N = 677) 
% mask_sens =  ~isnan(megtusalen_meg.exist_sens);
fprintf('%d participants that fullfiled the inclusion criteria and had MEG data.\n', sum(mask_diag & mask_age & mask_gender & ~mask_gds & mask_mriok & mask_mmse & mask_diagcog & mask_sens));

% 7. Participants with a power spectrum in sensor space (N = 617)
mask_pow = ~isnan(megtusalen_meg.exist_pow_sources);
fprintf('%d participants that fullfiled the inclusion criteria and had MEG ans power data.\n', sum(mask_diag & mask_age & mask_gender & ~mask_gds & mask_mriok & mask_mmse & mask_diagcog & mask_sens & mask_pow));

mask = mask_diag & mask_age & mask_gender & ~mask_gds & mask_mriok & mask_mmse & mask_diagcog & mask_sens;

%% Same exlcusion criteria, different order
% 1. Participant must have a raw MEG recording(sensor data)
% 2. Participant must have a group label
% 3. Participant must have basic demographic data (age, gender)
% 4. Participant must have an ok MRI report (no tumors, no ictus)
% 5. Healthy participants must have a MMSE report >= 26
% 6. For healthy controls, participant must not have a negative
% neuropsychological assessment.

fprintf('%d participants with MEG data.\n', sum(mask_sens));
fprintf('%d participants with MEG data and group label.\n', sum(mask_sens & mask_diag));
fprintf('%d participants with MEG data, group label and demographics.\n', sum(mask_sens & mask_diag & mask_age & mask_gender));

fprintf('%d participants with MEG data, group label and demographics and ok mri.\n', sum(mask_sens & mask_diag & mask_age & mask_gender & mask_mriok));
fprintf('%d participants with MEG data, group label and demographics and ok mri and with ok mmse.\n', sum(mask_sens & mask_diag & mask_age & mask_gender & mask_mriok & mask_mmse));
fprintf('%d participants with MEG data, group label and demographics and ok mri and healthy & with ok mmse and healthy.\n', sum(mask_sens & mask_diag & mask_age & mask_gender & mask_mriok & mask_mmse & ~mask_gds & mask_diagcog));

mask_mmse = ~(mask_cn & megtusalen_sample.mmse_extended < 26);
mask_diagcog = ~(mask_cn & megtusalen_sample.diagcog <2);
mask_nothealthy = mask_cn & (or(megtusalen_sample.diagcog <2,megtusalen_sample.mmse_extended < 26));
fprintf('%d participants with MEG data, group label, demographics and healthy.\n', sum(mask_sens & mask_diag & mask_age & mask_gender & ~mask_nothealthy));


%% Divide participants by groups

% diag labels
%  1 = Control (de MCI)
%  2 = Control con QSM
%  3 = DCLa (solo amnesia)
%  4 = DCLm (multidominio con amnesia)
%  5 = DCLu (multidominio sin amnesia)
%  6 = AD
%  7 = control con antecedentes de AD
%  8 = control sin QSM
%  9 = control sin antecedentes de AD

age = megtusalen_sample.age;
sex = megtusalen_sample.sex; % 1 male, 2 female

% Healthy
hc = sum(diag == [1, 8, 9],2); % N = 245
hc = hc & mask;
fprintf('%d HC, female %d, male %d, age %.1f (%.1f).\n', sum(hc), sum(sex(hc) == 2), sum(sex(hc) == 1),  mean(age(hc)), std(age(hc)));

% Healthy with family history of AD
fam = diag == 7; % N = 168
fam = fam & mask;
fprintf('%d Family+, female %d, male %d, age %.1f (%.1f).\n', sum(fam), sum(sex(fam) == 2), sum(sex(fam) == 1),  mean(age(fam)), std(age(fam)));

% Subjective Cognitive Decline
scd = diag == 2; % N = 107
scd = scd & mask;
fprintf('%d SCD, female %d, male %d, age %.1f (%.1f).\n', sum(scd), sum(sex(scd) == 2), sum(sex(scd) == 1),  mean(age(scd)), std(age(scd)));

% Mild Cognitive Impairment
mci = sum(diag == [3, 4, 5],2); % N = 185
mci = mci & mask;
fprintf('%d MCI, female %d, male %d, age %.1f (%.1f).\n', sum(mci), sum(sex(mci) == 2), sum(sex(mci) == 1),  mean(age(mci)), std(age(mci)));

% Alzheimer's Disease
ad = diag == 6; % N = 25
ad = ad & mask;
fprintf('%d AD, female %d, male %d, age %.1f (%.1f).\n', sum(ad), sum(sex(ad) == 2), sum(sex(ad) == 1),  mean(age(ad)), std(age(ad)));

%% Divide participants by study
umeg_mask = startsWith(megtusalen_sample.id_meg,'U');
nemos_mask = startsWith(megtusalen_sample.id_meg,'N');
familiares_mask = startsWith(megtusalen_sample.id_meg,'F');

umeg = megtusalen_sample(umeg_mask & mask,:);
nemos = megtusalen_sample(nemos_mask & mask,:);
familiares = megtusalen_sample(familiares_mask & mask,:);

% diag labels
%  1 = Control (de MCI)
%  2 = Control con QSM
%  3 = DCLa (solo amnesia)
%  4 = DCLm (multidominio con amnesia)
%  5 = DCLu (multidominio sin amnesia)
%  6 = AD
%  7 = control con antecedentes de AD
%  8 = control sin QSM
%  9 = control sin antecedentes de AD

% UMEC: 2, 3, 8
unique(umeg.diag);
fprintf('----%d participants from UMEG: %d SCD-, %d SCD+, %d MCIa .\n', height(umeg), sum(umeg.diag == 8), sum(umeg.diag == 2), sum(umeg.diag == 3));

% NEMOS: 1, 3, 4, 6
unique(nemos.diag);
fprintf('----%d participants from NEMOS: \n%d HC, %d MCIa, %d MCIm, %d AD.\n', height(nemos), sum(nemos.diag == 1), sum(nemos.diag == 3), sum(nemos.diag == 4), sum(nemos.diag == 6));

% FAM: 7, 9
unique(familiares.diag);
fprintf('----%d participants from Familiares: %d FH+, %d FH-.\n', height(familiares), sum(familiares.diag == 7), sum(familiares.diag == 9));
