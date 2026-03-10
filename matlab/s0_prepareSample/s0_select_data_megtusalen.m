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

% Information about MEG Data. We only consider up to FAM-235
megtusalen_meg = readtable(excel_file,'Sheet','megdata',ReadVariableNames=true, VariableNamesRange='A1:I1', DataRange="A2:I730");

% Information about demographic data
megtusalen_sample = readtable(excel_file,'Sheet','sample',ReadVariableNames=true, VariableNamesRange='A1:BQ1', DataRange="A2:BQ730");

% Clinical information based on MRI (existance of tumors, hemorrages, etc.)
megtusalen_mri = readtable(excel_file,'Sheet','mri_reports',ReadVariableNames=true, VariableNamesRange='A1:AM1', DataRange="A2:AM730");

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


%% Inclusion and exclusion criteria

% 1. Participant must have a group label
% 2. Participant must have basic demographic data (age, gender)
% 3. Participant must have MEG data
% 4. Participant must have an ok MRI (no tumors, no ictus)
% 5. Participant must not be depressed (not GDS > 14 )
% 6. Healthy participants must not have have a MMSE report < 26
% 7. Healthy participants must not have a negative neuropsychological assessment.

fprintf('\n\n%d initial participants.\n', n);

% 1. Participants with a defined group label.
mask_diag = ~isnan(megtusalen_sample.diag);
fprintf('\t%d participants did not have a group label.\n', n - sum(mask_diag));
mask_cum = mask_diag;
n_cum = sum(mask_cum);
fprintf('%d participants with diagnostic data.\n', n_cum);


% 2. Participants with demographic data
mask_age = ~isnan(megtusalen_sample.age);
mask_gender = ~isnan(megtusalen_sample.sex); 
fprintf('\t%d participants did not have age data.\n', n_cum - sum(mask_age));
fprintf('\t%d participants did not have sex data.\n', n_cum - sum(mask_gender));
mask_cum = mask_cum & mask_age & mask_gender;
n_cum = sum(mask_cum);
fprintf('%d participants with diagnostic and demographic data.\n', n_cum);

% 3. Participants with MEG data
mask_sens =  megtusalen_meg.missing_sens == 0;
% mask_sens =  ~isnan(megtusalen_meg.exist_sens); % Old field in excel file, it does not match dropbox list
fprintf('\t%d participants did not have a MEG recording.\n', n_cum - sum(mask_sens));
mask_cum = mask_cum & mask_sens;
n_cum = sum(mask_cum);
fprintf('%d participants with MEG data.\n', n_cum);

% Participants with MRI data
mask_mri = megtusalen_mri.ExisteT1;
fprintf('\t%d participants did not have an MRI.\n', n_cum - sum(mask_mri));
mask_cum = mask_cum & mask_mri;
n_cum = sum(mask_cum);
fprintf('%d participants with MRI data.\n', n_cum);

% Participants with a 'tumor' on their mri report.
mri_diag = megtusalen_mri.diagnostic;
mri_class = megtusalen_mri.classification;
diag_tumor = contains(mri_diag,'tumor');
class_tumor = contains(mri_class,'tumor');
mask_tumor = mask_cum & or(diag_tumor,class_tumor);
mask_notumor = mask_cum & ~or(diag_tumor,class_tumor);
fprintf('\t%d participants have a tumor.\n', sum(mask_tumor));

% Participants wiht a large lession (hemorragic, ischemic, etc.) on their mri report
mri_lession = megtusalen_mri.x1LargeLesion;
mask_lession = mask_cum & ~strcmp(mri_lession,'nan');
mask_nolession = mask_cum & strcmp(mri_lession,'nan');
fprintf('\t%d participants have a large lession.\n', sum(mask_lession));

% 4. Participants with an ok MRI (has an MRI without tumors or ictus).
mask_mriok = mask_notumor & mask_nolession;
mask_cum = mask_mriok;
n_cum = sum(mask_cum);
fprintf('%d participants with ok MRI.\n', n_cum);

% 5. Participants that are not depressed (not(GDS > 14))
mask_gds = mask_cum & megtusalen_sample.GDS_depres > 14;
mask_nogds = mask_cum & ~(megtusalen_sample.GDS_depres > 14);
fprintf('\t%d participants have GDS > 14.\n', sum(mask_gds));
mask_cum = mask_nogds;
n_cum = sum(mask_cum);
fprintf('%d participants without depression simptoms.\n', n_cum);

% 5. Healthy participants must not have an (adjusted) MMSE report < 26
cn  = [1, 8, 9];
mask_cn  = any(megtusalen_sample.diag == cn ,2);
mask_mmsebad = mask_cum & mask_cn & (megtusalen_sample.mmse_extended < 26);
mask_mmseok = mask_cum & ~mask_mmsebad;
fprintf('\t%d participants belonging to the healthy group had an (adjusted) MMSE < 26.\n', sum(mask_mmsebad));
mask_cum = mask_mmseok;
n_cum = sum(mask_cum);
fprintf('%d participants with mmse concording to their group.\n', n_cum);


% 6. Healthy participants must not have a negative neuropsychological assessment
mask_nothealthy = mask_cum & mask_cn & megtusalen_sample.diagcog < 2;
mask_ishealthy = mask_cum & ~mask_nothealthy;
fprintf('\t%d participants belonging to the healthy group had a negative neuropsychological assessment.\n', sum(mask_nothealthy));
mask_cum = mask_ishealthy;
n_cum = sum(mask_cum);
fprintf('%d participants with concording neuropsychological assessment.\n\n\n', n_cum);


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
diag = megtusalen_sample.diag;

% Healthy
hc = any(diag == [1, 8, 9],2);
hc = hc & mask_cum;
fprintf('%d HC, female %d, male %d, age %.1f (%.1f).\n', sum(hc), sum(sex(hc) == 2), sum(sex(hc) == 1),  mean(age(hc)), std(age(hc)));

% Healthy with family history of AD
fam = diag == 7; % N = 168
fam = fam & mask_cum;
fprintf('%d Family+, female %d, male %d, age %.1f (%.1f).\n', sum(fam), sum(sex(fam) == 2), sum(sex(fam) == 1),  mean(age(fam)), std(age(fam)));

% Subjective Cognitive Decline
scd = diag == 2; % N = 107
scd = scd & mask_cum;
fprintf('%d SCD, female %d, male %d, age %.1f (%.1f).\n', sum(scd), sum(sex(scd) == 2), sum(sex(scd) == 1),  mean(age(scd)), std(age(scd)));

% Mild Cognitive Impairment
mci = any(megtusalen_sample.diag == [3, 4, 5],2);
mci = mci & mask_cum;
fprintf('%d MCI, female %d, male %d, age %.1f (%.1f).\n', sum(mci), sum(sex(mci) == 2), sum(sex(mci) == 1),  mean(age(mci)), std(age(mci)));

% Alzheimer's Disease
ad = diag == 6; 
ad = ad & mask_cum;
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
