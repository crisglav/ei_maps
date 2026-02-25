% List beamformers downloaded from dropbox
% https://www.dropbox.com/home/Proyectos/Megtusalen/data/sources/beamformersLow

clear all
close all
clc

project_root  = 'C:\Users\Cristina\megtusalen';
sensors_path = fullfile(project_root,'data','segments');
sources_path = fullfile(project_root,'data','sources','lcmv');

%% PARTICIPANTS SAMPLE EXCEL
% Load participant sample
participants = readtable('../../data/participant_sample.xlsx');
participants.group_simp = categorical (participants.group_simp);
participants.project = categorical (participants.project);

% Dived by project group
% Divide participants by project
fam = participants(participants.project == 'FAM', :);
nemos = participants(participants.project == 'NEMOS', :);
umec = participants(participants.project == 'UMEC', :);
% umec = umec(1:229,:); % Only 229 with diagnosis
% Hard coded last available id
last_fam = 235;
last_nemos = 240;
last_umec = 254;

healhty = participants.superhealthy == 1 & participants.missing_lcmv == 0;
ad = participants.group_simp == 'AD' & participants.missing_lcmv == 0;
mci = participants.group_simp == 'MCI' & participants.missing_lcmv == 0;
scd = participants.group_simp == 'SCD' & participants.missing_lcmv == 0;
fh = participants.group_simp == 'FH' & participants.missing_lcmv == 0;

fprintf('PARTICIPANTS table\n');
fprintf('---- %d HEALTHY\n', sum(healhty));
fprintf('---- %d AD\n', sum(ad));
fprintf('---- %d MCI\n', sum(mci));
fprintf('---- %d SCD\n', sum(scd));
fprintf('---- %d FH\n', sum(fh));
sum(healhty) + sum(ad) + sum(mci) + sum(scd) + sum(fh);
sum(participants.missing_lcmv==0); % I have these meg files
% However I can't use all of them because
% - some do not have a diagnosis
% - some healthy subjects are not really healthy

% Discard MEG:
discard_nogroup = participants.missing_lcmv == 0 & isundefined(participants.group_simp);
discard_nohealthy = participants.missing_lcmv == 0 & participants.group_simp == 'HC' & participants.superhealthy == 0;

%% BEAMFORMER FILES
files_lcmv = dir (fullfile( sources_path, '*.mat'));
files_lcmv = {files_lcmv.name};

% Divide files by project
fam_lcmv = files_lcmv(startsWith(files_lcmv, 'FAM-'));
nemos_lcmv = files_lcmv(startsWith(files_lcmv, 'NEMOS-'));
umec_lcmv = files_lcmv(startsWith(files_lcmv, 'UMEC-'));

% Extract missing subjects per project
tokens = regexp(fam_lcmv, 'FAM-(\d+)_', 'tokens');
subject_ids = cellfun(@(x) str2double(x{1}), tokens);
missing_fam_lcmv = setdiff(1:last_fam, subject_ids);

tokens = regexp(nemos_lcmv, 'NEMOS-(\d+)_', 'tokens');
subject_ids = cellfun(@(x) str2double(x{1}), tokens);
missing_nemos_lcmv = setdiff(1:last_nemos, subject_ids);

tokens = regexp(umec_lcmv, 'UMEC-(\d+)_', 'tokens');
subject_ids = cellfun(@(x) str2double(x{1}), tokens);
missing_umec_lcmv = setdiff(1:last_umec, subject_ids);

% Print on screen the number of files per project
fprintf('LCMV files\n')
fprintf('---- %d UMEC\n', size(umec_lcmv,2));
fprintf('---- %d NEMOS\n', size(nemos_lcmv,2));
fprintf('---- %d FAM\n', size(fam_lcmv,2));


%% SENS FILES
files_sens = dir (fullfile( sensors_path, '*.mat'));
files_sens = {files_sens.name};

% Divide files by project
fam_sens = files_sens(startsWith(files_sens, 'FAM-'));
nemos_sens = files_sens(startsWith(files_sens, 'NEMOS-'));
umec_sens = files_sens(startsWith(files_sens, 'UMEC-'));

% Extract missing subjects per project
tokens = regexp(fam_sens, 'FAM-(\d+)_', 'tokens');
subject_ids = cellfun(@(x) str2double(x{1}), tokens);
missing_fam_sens = setdiff(1:last_fam, subject_ids);

tokens = regexp(nemos_sens, 'NEMOS-(\d+)_', 'tokens');
subject_ids = cellfun(@(x) str2double(x{1}), tokens);
missing_nemos_sens = setdiff(1:last_nemos, subject_ids);

tokens = regexp(umec_sens, 'UMEC-(\d+)_', 'tokens');
subject_ids = cellfun(@(x) str2double(x{1}), tokens);
missing_umec_sens = setdiff(1:last_umec, subject_ids);

% Print on screen the number of files per project
fprintf('SENS files\n')
fprintf('---- %d UMEC\n', size(umec_sens,2));
fprintf('---- %d NEMOS\n', size(nemos_sens,2));
fprintf('---- %d FAM\n', size(fam_sens,2));


