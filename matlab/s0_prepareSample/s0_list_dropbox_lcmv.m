% List beamformers downloaded from dropbox
% https://www.dropbox.com/home/Proyectos/Megtusalen/data/sources/beamformersLow

clear all
close all
clc

project_root  = 'C:\Users\Cristina\megtusalen\data\sources\lcmv';

files = dir (fullfile( project_root, '*.mat'));
filenames = {files.name};

% Divide files by project
% Keep only FAM files
fam_files = filenames(startsWith(filenames, 'FAM-'));
nemos_files = filenames(startsWith(filenames, 'NEMOS-'));
umec_files = filenames(startsWith(filenames, 'UMEC-'));

% Extract missing subjects per project
tokens = regexp(fam_files, 'FAM-(\d+)_', 'tokens');
subject_ids = cellfun(@(x) str2double(x{1}), tokens);
missing = setdiff(1:max(subject_ids), subject_ids)

tokens = regexp(nemos_files, 'NEMOS-(\d+)_', 'tokens');
subject_ids = cellfun(@(x) str2double(x{1}), tokens);
missing = setdiff(1:max(subject_ids), subject_ids)

tokens = regexp(umec_files, 'UMEC-(\d+)_', 'tokens');
subject_ids = cellfun(@(x) str2double(x{1}), tokens);
missing = setdiff(1:max(subject_ids), subject_ids);

% Load participant sample
participants = readtable('../../data/participant_sample.xlsx');
participants.group_simp = categorical (participants.group_simp);
healhty = participants.group_simp == 'HC' & participants.superhealthy == 1;
ad = participants.group_simp == 'AD';
mci = participants.group_simp == 'MCI';
scd = participants.group_simp == 'SCD';
fh = participants.group_simp == 'FH';


fprintf('---- %d HEALTHY\n', sum(healhty));
fprintf('---- %d AD\n', sum(ad));
fprintf('---- %d MCI\n', sum(mci));
fprintf('---- %d SCD\n', sum(scd));
fprintf('---- %d FH\n', sum(fh));
sum(healhty) + sum(ad) + sum(mci) + sum(scd) + sum(fh)
