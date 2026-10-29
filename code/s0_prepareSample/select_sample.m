%% Select sample from Megtusalen dataset
% 
% This script selects the sample to be used at the ei_maps project based on
% the inclusion and exclusion criteria defined below.
%
% The diagcog score was created to assess which participants labeled 
% healthy passed the neuropsychological scores. For more information on how
% this variable was created, check the script
% megtusalen_validation2026/code/generate_diagcog.m
%
% Cristina Gil Avila, 27/08/2026, C3N


clear all;
close all;
clc;
%% Load participants data
date = datetime('now','Format','yyyyMMdd');

% Whether to include converters L2 as AD or not
conv_flag = false;

% Read config from json file
txt = fileread(fullfile ('..', 'config_megtusalen.json' ));
config = jsondecode(txt);

% Load megtusalen first session data with diagcog scores.
megtusalen = readtable(config.path.participants_L1, 'Filetype', 'spreadsheet');
n = height(megtusalen);

% Load second session data to increase the size of the AD group
opts = detectImportOptions(config.path.participants_L2);
opts.VariableTypes = {'char','char','single','categorical','logical','logical','logical','char'};
converters = readtable(config.path.participants_L2,opts);

% Create participants table based on selected megtusalen colums
participants = megtusalen(:,{'project_id', 'participant_id', 'age',	'sex', 'group', 'diagnosis', ...
    'converter', 'conversion_time', 'evolution_time', 'family_history', 'edu_years', 'GDS_15', ...
    'mmse_adj', 'LM_immediate_units', 'LM_delayed_units', 'APOE', 'diagcog','has_meg','has_mri','mriok', 'recording_id_orig'});

% Replace ses1 of MCI participants that converted to AD and have a second
% longitudinal recording by ses2 of those participants to increse the N of
% our AD group.
participants.session = repmat({'L1'}, n, 1);
if conv_flag
    conv_mask = and(converters.diagnosis_L2 == 'AD', converters.has_meg);
    participants.group(conv_mask) = {'CONV'};
    participants.diagnosis(conv_mask) = {'AD'};
    participants.age(conv_mask) = converters.age_L2(conv_mask);
    participants.session(conv_mask) = {'L2'};
end
% Transform to categorical diagnosis and sex variables
participants.diagnosis = categorical(participants.diagnosis);
participants.sex = categorical(participants.sex);


%% Inclusion and exclusion criteria

% Participant must not be included in several studies.
% 1. Participant must have a confirmed group label.
% 2. Participant must have basic demographic data (age, gender)
% 3. Participant must have MEG data
% 4. Participant must have an ok MRI (no tumors, no large lessions)
% 5. Participant must not have a Global Depression Score = 15
% 6. Healthy participants must not have have a MMSE report < 26
% 7. Healthy participants must not have a negative neuropsychological assessment.

% Create log file
log_file = 'participants_inclusion_exclusion.log';
fid = fopen(log_file,'w');

fprintf(fid,'\n\n%d participants in the initial sample.\n', n);
included = ones(n,1);
n_included = sum(included);

% Exclude duplicated participant
mask_notduplicated = included & ~contains(participants.recording_id_orig,'FAMMA018');
fprintf(fid,'\t%d participants are duplicated.\n', n_included - sum(mask_notduplicated));
included = mask_notduplicated;
n_included = sum(included);
fprintf(fid,'%d participants with ok diagnostic data.\n', n_included);

% 1. Participants with a ok defined group label and not duplicated
mask_diag = ~ismissing(participants.diagnosis);
fprintf(fid,'\t%d participants did not have a group label.\n', n_included - sum(mask_diag));
included = mask_diag;
n_included = sum(included);
fprintf(fid,'%d participants with diagnostic data.\n', n_included);

% NEW
% For the purpose of this study we are not interested in family history,
% only in that the participants are healthy.

% % Exclude participants without a congruent group label. I.e., check that for FAM the group label is congruent with
% % family_history
% isFAM = strcmp(participants.project_id, 'FAM');
% hasFHpos = categorical(participants.group) == 'FHpos';
% hasfam_history = any(participants.family_history == [1, 3], 2) & isFAM;
% mask_diagok = included & (hasFHpos == hasfam_history);
% 
% fprintf(fid,'\t%d participants did not have a congruent group label.\n', n_included - sum(mask_diagok));
% included = mask_diagok;
% n_included = sum(included);
% fprintf(fid,'%d participants with ok diagnostic data.\n', n_included);

% 2. Participants with demographic data
mask_age = included & ~isnan(participants.age);
fprintf(fid,'\t%d participants did not have age data.\n', n_included - sum(mask_age));
included =  mask_age;
n_included = sum(included);
fprintf(fid,'%d participants with age.\n', n_included);

mask_gender = included & ~ismissing(participants.sex); 
fprintf(fid,'\t%d participants did not have sex data.\n', n_included - sum(mask_gender));
included = mask_gender;
n_included = sum(included);
fprintf(fid,'%d participants with diagnostic and demographic data.\n', n_included);

% 3. Participants with MEG data
mask_sens =  included & participants.has_meg == 1;
fprintf(fid,'\t%d participants did not have a MEG recording.\n', n_included - sum(mask_sens));
included = mask_sens;
n_included = sum(included);
fprintf(fid,'%d participants with MEG data.\n', n_included);

% 4. Participants with ok MRI data
mask_mri = included & participants.has_mri == 1;
fprintf(fid,'\t%d participants did not have an MRI.\n', n_included - sum(mask_mri));
included = mask_mri;
n_included = sum(included);
fprintf(fid,'%d participants with MRI data.\n', n_included);

% Participants with an ok MRI (has an MRI without tumors or large ischemic or hemorragic lessions).
mask_mriok = included & participants.mriok == 1;
fprintf(fid,'\t%d participants had tumors or large lessions on their MRI.\n', n_included - sum(mask_mriok));
included = mask_mriok;
n_included = sum(included);
fprintf(fid,'%d participants with ok MRI.\n', n_included);

% 5. Participants with Global Depression Score == 15
mask_gdsok = included & ~(participants.GDS_15 > 14);
fprintf(fid,'\t%d participants have GDS > 14.\n', n_included - sum(mask_gdsok));
included = mask_gdsok;
n_included = sum(included);
fprintf(fid,'%d participants without depression simptoms.\n', n_included);

% 5. Healthy participants must not have an (adjusted) MMSE report < 26
isHC = participants.diagnosis == 'HC';
mask_mmsebad = included & isHC & (participants.mmse_adj < 26);
mask_mmseok = included & ~mask_mmsebad;
fprintf(fid,'\t%d participants belonging to the healthy group had an (adjusted) MMSE < 26.\n', sum(mask_mmsebad));
included = mask_mmseok;
n_included = sum(included);
fprintf(fid,'%d participants with mmse concording to their group.\n', n_included);

% 6. Healthy participants must not have a negative neuropsychological assessment
mask_nothealthy = included & isHC & (participants.diagcog == 0);
mask_ishealthy = included & ~mask_nothealthy;
fprintf(fid,'\t%d participants belonging to the healthy group had a negative neuropsychological assessment.\n', sum(mask_nothealthy));
included = mask_ishealthy;
n_included = sum(included);
fprintf(fid,'%d participants with concording neuropsychological assessment.\n', n_included);

%%
% Check if a participant has a calculated beamformer based on the dropbox
% data

% Beamformer files
project_root  = 'C:\Users\Cristina\megtusalen';
sources_path = fullfile(project_root,'L1','data','sources','lcmv');

files_lcmv = dir (fullfile( sources_path, '*.mat'));
files_lcmv = {files_lcmv.name};
files_lcmv_id = cellfun(@(x) strtok(x, '_'), files_lcmv, 'UniformOutput', false);

has_lcmv = ismember(participants.participant_id, files_lcmv_id);
participants.has_lcmv = has_lcmv;

% 7. Do not include participants that have not lcmv calculated
mask_lcmv = included & has_lcmv;
fprintf(fid,'\t%d participants do not have lcmv calculated.\n', n_included - sum(mask_lcmv));
included = mask_lcmv;
n_included = sum(included);
fprintf(fid,'%d participants with lcmv calculated.\n\n\n', n_included);
fclose(fid);

% Add included column to table
participants.included = included;

%% Save data
participants_included = participants(included,{'participant_id','session','age','sex','diagnosis','group','converter','conversion_time','family_history','edu_years','APOE','mmse_adj', 'LM_immediate_units', 'LM_delayed_units'});
if conv_flag
    filename = strcat('../../data/participants/participants_', string(date), '.xlsx');
else
    filename = strcat('../../data/participants/participants_L1_', string(date), '.xlsx');
end

writetable(participants_included, filename);


