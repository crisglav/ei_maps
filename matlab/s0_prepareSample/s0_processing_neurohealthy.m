% Script that checks healthy control diagnosis based on the 8 neuropsychological
% assessments common to all Megtusalen subjects.
%
% Input data: 
%       - supermegtusalen_global_vOct2024.xlsx (Sample info with
%         variables animales, F, A, S, sumFAS handregistered by Lucia H)
%       - supermegtusalen_global_v2024_nans.xlsx (all data sheets)
%
% Output data: 
%       - supermegtusalen_global_v2025_diagcog.xlsx (all data sheets including
%         in 'sample' sheet the variable diagcog that assigns a diagnosis based on
%         the neuropsychological tests). It can be exported only
%         participants with a healhy diagnosis, with age data and with MMSE
%         < 26 or all the participants in the original sample (See last
%         part of the script).
%
% Diacog coding
%       NaN - Not enough neuropsychological tests availabe to determine diagnosis
%       0 - Participant not healthy (passed less than 7 test, having performed more than 2 tests)
%       1 - Participant healthy (passed 7 or 8 tests)
%       2 - Participant superhealthy (passed 8 tests)
%
% TO DO:
% - Add references to neuropyschological tests and reference
% thresholds/parameters
% - Add thresholds for people younger than 50
% 
% Lucia Hernandez, C3N, 2024
% Cristina Gil, C3N, major revision 17/03/2025

clear all
close all
clc

%% Load excel data
data_all = readtable('../../data/supermegtusalen_global_vOct2024.xlsx');
out_file = '../../data/supermegtusalen_global_v2025_diagcog.xlsx';

% Load additional excel sheets from supermegtusalen excel file
excel_file = '../../data/supermegtusalen_global_v2024_nans.xlsx';
sheetnames = {'sample','megdata', 'genes', 'dtis', 'vols_aseg_lobes', 'vols_aparc', 'vols_exvivo', 'vols_wm', 'wmh', 'mri_reports'};


n = size(data_all,1);               % Original sample size

% Extract variables from table
age = data_all.age;                 % Age
mmse = data_all.MMSE;               % Original MMSE score
a_os_esc = data_all.a_os_esc;       % Scholarization years

% Set thresholds
param.age = 50;                     % Age threshold
param.cn = [1, 2, 7, 8, 9];         % Diagnosis of healthy participants
param.mmse = 26;                    % MMSE score
param.mmse_age = 75;                % MMSE age threshold
param.escol = [8, 17];              % Education years threshold for MMSE
param.escol_diginv = [9, 17];       % Education years threshold for inverse digit task
param.ageranks = [50 56; 57 59; 60 62; 63 65; 66 68; 69 71; 72 74; 75 77; 78 80; 81 90];
param.tmta_time = [101; 109; 119; 111; 124; 157; 159; 159; 160; 159];
param.tmtb_time = [380; 380; 380; 401; 317; 420; 448; 461; 428; 428];
param.fas_sem = [13, 12, 11, 11, 11, 10, 10, 9, 8, 9];

param.export_all = true;           % Variable to export all participants or only healthy participants

fprintf('%d subjects in original sample.\n', n);
%% Filter participans by controls
mask_healthy = any(data_all.diag == param.cn,2);
fprintf('%d healthy participants in original sample.\n', sum(mask_healthy));

%% Filter participants by existance of age data and age threshold
% Do not take into account participants younger than param.age or without
% information about age.
mask_age = ~isnan(age);
fprintf('%d subjects with age data.\n', sum(mask_age));

mask_age_thres = mask_age & age >= param.age;
fprintf('%d healthy participants with age data and older than %d.\n', sum(mask_healthy & mask_age_thres), param.age);

%% Filter participants who have an (adjusted) MMSE < 26
% Note: For participants who do not have information about education years,
% use their original mmse

% Create a new column mmse_adj
mmse_adj = nan(n,1);
for isuj = 1 : n

    % Skip if participant has no age, their age is lower than param.age or
    % if participant does not have information about education years
    if isnan(age(isuj)) || age(isuj) < param.age || isnan(a_os_esc(isuj))
        continue;
    end

    % Compute adjusted mmse
    % If the chronological age is equal or higher than the MMSE age threshold (26)
    if age(isuj) >= param.mmse_age

        % Education years lower or equal than 8, increase MMSE by 2
        if a_os_esc(isuj) <= param.escol(1)
            mmse_adj(isuj) = mmse(isuj)+2;

        % Education years between 9 and 17, increase MMSE by 1
        elseif a_os_esc(isuj) > param.escol(1) && a_os_esc(isuj) <= param.escol(2)
            mmse_adj(isuj) = mmse(isuj)+1;

        % 18 or more education years, use MMSE age
        elseif data_all.a_os_esc(isuj) >param.escol(2)
            mmse_adj(isuj) = mmse(isuj);
        end

    % If the chronological age is lower than the MMSE age threshold
    else

        % Education years lower or equal than 8, increase MMSE by 1
        if a_os_esc(isuj) <= param.escol(1)
            mmse_adj(isuj) = mmse(isuj)+1;

        % Education years between 9 and 17, use MMSE age
        elseif data_all.a_os_esc(isuj) > param.escol(1) && data_all.a_os_esc(isuj) <= param.escol(2)
            mmse_adj(isuj) = mmse(isuj);

        % 18 or more education years, decrease MMSE one year
        elseif data_all.a_os_esc(isuj) >param.escol(2)
            mmse_adj(isuj) = mmse(isuj)-1;
        end
    end


    % Threshold adjusted mmse age for those participants that scored higher
    % than 30
    if mmse_adj(isuj) > 30
        mmse_adj(isuj) = 30;
    end
end

% Extend MMSE to participants who are missing the variable years of
% education
mmse_extended = mmse_adj;
mmse_extended(isnan(a_os_esc)) = mmse(isnan(a_os_esc));

% Create a new column mmse_ok
mmse_ok = nan(n,1);
mmse_ok(mmse_extended < param.mmse) = 0;
mmse_ok(mmse_extended >= param.mmse) = 1;

fprintf('%d healhty participants with age data, older than %d, and with variable mmse_adj.\n', sum(mask_healthy & mask_age_thres & ~isnan(mmse_adj)), param.age);
fprintf('%d healthy participants with age data, older than %d, and with variable mmse_extended.\n', sum(mask_healthy & mask_age_thres & ~isnan(mmse_extended)), param.age);
fprintf('%d healthy participants with age data, older than %d, and with mmse_extended < 26.\n', sum(mask_healthy & mask_age_thres & (mmse_ok==1)), param.age);

%% Adjust the eight neuropsychological tests that were common to all Megtusalen participants and assess tests
% Note: if participant is missing a test, their test result will be set to
% -1 instead of nan. This is to distinguish nan because of missing
% demographic data from missing test data.

% 1. Immediate logic memory (memoria lógica inmediata)
% Variable to save tests results: 1 - passed test, 0 - failed test.
mem_log_inm_result = nan(n,1);

for isuj = 1 : n
    
    % Skip if participant has no age, or their age is lower than param.age
    if ~mask_age_thres(isuj)
        continue;
    end

   % If there is no test data, set -1
    if isnan(data_all.mem_log_uni_inm(isuj))
        mem_log_inm_result(isuj) = -1;
        continue;
    end

    % Assess test based on age thresholds specific to the test
    if age(isuj) >= 50 && age(isuj) < 55 && data_all.mem_log_uni_inm(isuj) >= 20
        mem_log_inm_result(isuj) = 1;
    elseif age(isuj) >= 50 && age(isuj) < 55 && data_all.mem_log_uni_inm(isuj) < 20
        mem_log_inm_result(isuj) = 0;
        
    elseif age(isuj) >= 55 && age(isuj) < 66 && data_all.mem_log_uni_inm(isuj) >= 15
         mem_log_inm_result(isuj) = 1;
    elseif age(isuj) >= 55 && age(isuj) < 66 && data_all.mem_log_uni_inm(isuj) < 15
         mem_log_inm_result(isuj) = 0;

    elseif age(isuj) >= 66 && age(isuj) < 74 && data_all.mem_log_uni_inm(isuj) >= 11
         mem_log_inm_result(isuj) = 1;
    elseif age(isuj) >= 66 && age(isuj) < 74 && data_all.mem_log_uni_inm(isuj) < 11
         mem_log_inm_result(isuj) = 0;
    
    elseif age(isuj) >= 74 && data_all.mem_log_uni_inm(isuj) >= 8
         mem_log_inm_result(isuj) = 1;
    elseif age(isuj) >= 74 && data_all.mem_log_uni_inm(isuj) < 8
         mem_log_inm_result(isuj) = 0;
    end 
end

fprintf('\n1. Immediate logic memory (memoria lógica inmediata) \n');
fprintf('%d healthy participants passed the test mem log uni inm \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & mem_log_inm_result == 1));
fprintf('%d healthy participants failed the test mem log uni inm \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & mem_log_inm_result == 0));
fprintf('%d healthy participants do not have the test mem log uni inm \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & mem_log_inm_result == -1));



% 2. Delayed logic memory (Memoria lógica demorada)
% Variable to save tests results: 1 - passed test, 0 - failed test.
mem_log_dem_result = nan(n,1);

for isuj = 1 : n
    
    % Skip if participant has no age, or their age is lower than param.age
    if ~mask_age_thres(isuj)
        continue;
    end

    % If there is no test data, set -1
    if isnan(data_all.mem_log_uni_dem(isuj))
        mem_log_dem_result(isuj) = -1;
        continue;
    end

    % Assess test based on age thresholds specific to the test
    if age(isuj) >= 50 && age(isuj) < 55 && data_all.mem_log_uni_dem(isuj) >= 9
        mem_log_dem_result(isuj) = 1;
    elseif age(isuj) >= 50 && age(isuj) < 55 && data_all.mem_log_uni_dem(isuj) < 9
        mem_log_dem_result(isuj) = 0;
        
    elseif age(isuj) >= 55 && age(isuj) < 66 && data_all.mem_log_uni_dem(isuj) >= 6
         mem_log_dem_result(isuj) = 1;
    elseif age(isuj) >= 55 && age(isuj) < 66 && data_all.mem_log_uni_dem(isuj) < 6
         mem_log_dem_result(isuj) = 0;

    elseif age(isuj) >= 66 && age(isuj) < 74 && data_all.mem_log_uni_dem(isuj) >= 2
         mem_log_dem_result(isuj) = 1;
    elseif age(isuj) >= 66 && age(isuj) < 74 && data_all.mem_log_uni_dem(isuj) < 2
         mem_log_dem_result(isuj) = 0;
    
    elseif age(isuj) >= 74 && data_all.mem_log_uni_dem(isuj) >= 1
         mem_log_dem_result(isuj) = 1;
    elseif age(isuj) >= 74 && data_all.mem_log_uni_dem(isuj) < 1
         mem_log_dem_result(isuj) = 0;
    end 
end

fprintf('\n2. Delayed logic memory (Memoria lógica demorada) \n');
fprintf('%d healthy participants passed the test mem log uni dem \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & mem_log_dem_result == 1));
fprintf('%d healthy participants failed the test mem log uni dem \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) &mem_log_dem_result == 0));
fprintf('%d healthy participants do not have the test mem log uni dem \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & mem_log_dem_result == -1));




% 3. Direct digit task (Dig directos). It measures attention span.
% Variable to save tests results: 1 - passed test, 0 - failed test.
dig_dir_result = nan(n,1);

% First adjust variable dig_direc by years of scholarization. If no data 
% availabe for scholarization years, use the original dig_direc score.
dig_dir_adj = nan(n,1);

for isuj = 1 : n

    % Skip if participant has no age, or their age is lower than param.age
    if ~mask_age_thres(isuj)
        continue;
    end

    % If there is no test data, set -1
    if isnan(data_all.dig_direc(isuj))
        dig_dir_adj(isuj) = -1;
        continue;
    end

    % If there is no variable years of scholarizaton, use the original
    % score
    if isnan(a_os_esc(isuj))
        dig_dir_adj(isuj) = data_all.dig_direc(isuj);
        continue;
    end

    if a_os_esc(isuj) <= param.escol(1)
        dig_dir_adj(isuj) = data_all.dig_direc(isuj) + 1;

    elseif a_os_esc(isuj) > param.escol(1) && a_os_esc(isuj) < param.escol(2)
        dig_dir_adj(isuj) = data_all.dig_direc(isuj);

    elseif a_os_esc(isuj) >= param.escol(2)
        dig_dir_adj(isuj) = data_all.dig_direc(isuj) - 1;

    end

end

% Assess test
dig_dir_result(dig_dir_adj >= 4) = 1;
dig_dir_result(dig_dir_adj < 4) = 0;
dig_dir_result(dig_dir_adj == -1) = -1;

fprintf('\n3. Direct digit task \n');
fprintf('%d healthy participants passed the test dig dir \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_dir_result == 1));
fprintf('%d healthy participants failed the test dig dir \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_dir_result == 0));
fprintf('%d healthy participants do not have the test dig dir \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_dir_result == -1));




% 4. Inverse digit task (Dig inversos). It measures working memory.
% Variable to save tests results: 1 - passed test, 0 - failed test.
dig_inv_result = nan(n,1);

% First adjust variable dig_direc by years of scholarization. If no data 
% availabe for scholarization years, use the original dig_inv score.
dig_inv_adj = nan(n,1);

for isuj = 1 : n

    % Skip if participant has no age, or their age is lower than param.age
    if ~mask_age_thres(isuj)
        continue;
    end

    % If there is no test data, set -1
    if isnan(data_all.dig_inv(isuj))
        dig_inv_adj(isuj) = -1;
        continue;
    end

    % If there is no variable years of scholarizaton, use original score
    if isnan(a_os_esc(isuj))
        dig_inv_adj(isuj) = data_all.dig_inv(isuj);
        continue;
    end

    if a_os_esc(isuj) <= param.escol_diginv(1)
        dig_inv_adj(isuj) = data_all.dig_inv(isuj) + 1;

    elseif a_os_esc(isuj) > param.escol_diginv(1) && a_os_esc(isuj) < param.escol_diginv(2)
        dig_inv_adj(isuj) = data_all.dig_inv(isuj);

    elseif a_os_esc(isuj) >= param.escol_diginv(2)
        dig_inv_adj(isuj) = data_all.dig_inv(isuj) - 1;

    end

end

% Assess test based on age ranks
for isuj = 1:n

    if age(isuj) >= 50 && age(isuj) <= 56
        if dig_inv_adj(isuj) >=3
            dig_inv_result(isuj) = 1;
        else
            dig_inv_result(isuj) = 0;
        end

    elseif age(isuj)> 56
        if dig_inv_adj(isuj) >= 2
            dig_inv_result(isuj) = 1;
        else
            dig_inv_result(isuj) = 0;
        end
    end
end
dig_inv_result(dig_inv_adj == -1) = -1;


fprintf('\n4. Inverse digit task \n');
fprintf('%d healthy participants passed the test dig inv \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_inv_result == 1));
fprintf('%d healthy participants failed the test dig inv \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_inv_result == 0));
fprintf('%d healthy participants do not have the test dig inv \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_inv_result == -1));




% 5. TMTA. It measures processing speed, sustained attention.
% Note: only the variable TMTA_time was used here and corrected. The variable
% TMTA_AC (aciertos) was not corrected because it was not reliable.
% Variable to save tests results: 1 - passed test, 0 - failed test.
tmta_result = nan(n,1);

for isuj = 1 : n

    % Skip if participant has no age, or their age is lower than param.age
    if ~mask_age_thres(isuj)
        continue;
    end

    % If there is no test data, set -1
    if isnan(data_all.TMTa_T(isuj))
        tmta_result(isuj) = -1;
        continue;
    end

    % Assess test based on specific age ranks
    for iage = 1:length(param.ageranks) 

        if age(isuj) >= param.ageranks(iage, 1) && age(isuj) <= param.ageranks(iage, 2) && data_all.TMTa_T(isuj) <= param.tmta_time(iage)
            tmta_result(isuj) = 1;

        elseif age(isuj) >= param.ageranks(iage, 1) && age(isuj) <= param.ageranks(iage, 2) && data_all.TMTa_T(isuj) > param.tmta_time(iage)
            tmta_result(isuj) = 0;

        end

    end 
end

fprintf('\n5. TMTA \n');
fprintf('%d healthy participants passed the test tmta \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & tmta_result == 1));
fprintf('%d healthy participants failed the test tmta \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & tmta_result == 0));
fprintf('%d healthy participants do not have the test tmta \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & tmta_result == -1));



% TMTB
% Variable to save tests results: 1 - passed test, 0 - failed test.
tmtb_result = nan(n,1);

for isuj = 1 : n

    % Skip if participant has no age, or their age is lower than param.age
    if ~mask_age_thres(isuj)
        continue;
    end

    % If there is no test data, set -1
    if isnan(data_all.TMTb_T(isuj))
        tmtb_result(isuj) = -1;
        continue;
    end

    % Assess test based on specific age ranks
    for iage = 1:length(param.ageranks) 

        if age(isuj) >= param.ageranks(iage, 1) && age(isuj) <= param.ageranks(iage, 2) && data_all.TMTb_T(isuj) <= param.tmtb_time(iage)
            tmtb_result(isuj) = 1;

        elseif age(isuj) >= param.ageranks(iage, 1) && age(isuj) <= param.ageranks(iage, 2) && data_all.TMTb_T(isuj) > param.tmtb_time(iage)
            tmtb_result(isuj) = 0;

        end

    end 
end

fprintf('\n5. TMTB \n');
fprintf('%d healthy participants passed the test tmtb \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & tmtb_result == 1));
fprintf('%d healthy participants failed the test tmtb \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & tmtb_result == 0));
fprintf('%d healthy participants do not have the test tmtb \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & tmtb_result == -1));




% 7. FAS phonology.
% Variable to save tests results: 1 - passed test, 0 - failed test.
fas_fon_result = nan(n,1);

for isuj = 1 : n

    % Skip if participant has no age, or their age is lower than param.age
    if ~mask_age_thres(isuj)
        continue;
    end

    % If there is no test data, set -1
    if isnan(data_all.sumFAS(isuj))
        fas_fon_result(isuj) = -1;
        continue;
    end


    % Assess test
    if age(isuj) < 60

        % Assume that the participant is in the low rank of years of
        % scholarization if the variable a_os_esc is missing
        if(a_os_esc(isuj) < 13 || isnan(a_os_esc(isuj)))

            if data_all.sumFAS(isuj) >= 27.55
                fas_fon_result(isuj) = 1;
            else
                fas_fon_result(isuj) = 0;
            end

        else % a_os_esc >= 13
            if data_all.sumFAS(isuj) >= 29.5
                fas_fon_result(isuj) = 1;
            else
                fas_fon_result(isuj) = 0;
            end

        end

    else % age(isuj >= 60)

        if(a_os_esc(isuj) < 13 || isnan(a_os_esc(isuj)))

            if data_all.sumFAS(isuj) >= 10.3
                fas_fon_result(isuj) = 1;
            else
                fas_fon_result(isuj) = 0;
            end

        else % a_os_esc >= 13
            if data_all.sumFAS(isuj) >= 29.5
                fas_fon_result(isuj) = 1;
            else
                fas_fon_result(isuj) = 0;
            end


        end
    end

end
fprintf('\n7. FAS fon \n');
fprintf('%d healthy participants passed the test FAS fon \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & fas_fon_result == 1));
fprintf('%d healthy participants failed the test FAS fon \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & fas_fon_result == 0));
fprintf('%d healthy participants do not have the test FAS fon \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & fas_fon_result == -1));



% 8. FAS semantics.
% Only use the variable animales, which was the only one common to the
% three Megtusalen studies.
% Variable to save tests results: 1 - passed test, 0 - failed test.
fas_sem_result = nan(n,1);

for isuj = 1 : n

    % Skip if participant has no age, or their age is lower than param.age
    if ~mask_age_thres(isuj)
        continue;
    end

    % If there is no test data, set -1
    if isnan(data_all.animales(isuj))
        fas_sem_result(isuj) = -1;
        continue;
    end

    % Assess test
    for iage = 1:size(param.ageranks,1)
        if age(isuj) >= param.ageranks(iage, 1) && age(isuj) <= param.ageranks(iage, 2) 
            
            if data_all.animales(isuj) >= param.fas_sem(iage)
                fas_sem_result(isuj) = 1;
            else
                fas_sem_result(isuj) = 0;
            end

        end
    end

end
fprintf('\n8. FAS sem \n');
fprintf('%d healthy participants passed the test FAS sem \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & fas_sem_result == 1));
fprintf('%d healthy participants failed the test FAS sem \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & fas_sem_result == 0));
fprintf('%d healthy participants do not have the test FAS sem \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & fas_sem_result == -1));



%% Classify healthy subjects
% The criterion to consider pathologic a subject is when they have two or
% more failed tests, having written at least 3 tests.

% Collate all tests
tests = [mem_log_inm_result, mem_log_dem_result, dig_dir_result, dig_inv_result, tmta_result, tmtb_result, fas_fon_result, fas_sem_result];

% Participants who have not completed any of the neuropyschological tests
no_neuro_atall = all(tests == -1,2);

% Participants who have not completed enough neuropsychological tests (2
% or less tests)
no_neuro = (sum(tests == -1 ,2) > 2) & ~no_neuro_atall;

% Participants who are not considered healthy (they failed two or more
% tests)
no_healthy = sum(tests == 1 ,2) < 7 & ~no_neuro_atall & ~no_neuro;

% Participants who are considered healthy (they failed one or zero tests)
healthy = sum(tests == 1 ,2) >= 7;

% Participants who are considered superhealthy (they did not fail any test)
superhealthy = sum(tests == 1 ,2) == 8;

fprintf('\nAssessment summary \n');
fprintf('%d healthy participants did not complete any neuropsychological test \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & no_neuro_atall));
fprintf('%d healthy participants did not complete enough neuropsychological tests \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & no_neuro));
fprintf('%d healthy participants failed two ore more tests \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & no_healthy));
fprintf('%d healthy participants failed one or zero tests \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & healthy));
fprintf('%d healthy participants failed zero tests \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & superhealthy));

% Create new variable diagcog with the final diagnosis based on
% neuropsychological tests
diagcog = nan(n,1);             % Not enough data to assess
diagcog(no_healthy) = 0;        % No healthy
diagcog(healthy) = 1;           % Healhty
diagcog(superhealthy) = 2;      % Superhealthy

%% Save database

for isheet = 1:numel(sheetnames)

    sheetname       = sheetnames{isheet};

    % Read sheet
    opts            = detectImportOptions(excel_file, 'Sheet', sheetname);
    opts.DataRange  = 'A2';
    data_out        = readtable(excel_file, opts, 'Sheet', sheetname);

    % Handle sample sheet differently
    if strcmp(sheetname, 'sample')
        % Add Lucia's computed columns and new computed columns to
        % Megtusalen sample sheet
        data_out.animales = data_all.animales;
        data_out.F = data_all.F;
        data_out.A = data_all.A;
        data_out.S = data_all.S;
        data_ouut.sumFAS = data_all.sumFAS;


        data_out.mmse_adj = mmse_adj;
        data_out.mmse_extended = mmse_extended;
        data_out.mmse_ok = mmse_ok;
        data_out.dig_dir_adj = dig_dir_adj;
        data_out.dig_inv_adj = dig_inv_adj;

        data_out.mem_log_inm_result = mem_log_inm_result;
        data_out.mem_log_dem_result = mem_log_dem_result;
        data_out.dig_dir_result = dig_dir_result;
        data_out.dig_inv_result = dig_inv_result;
        data_out.tmta_result = tmta_result;
        data_out.tmtb_result = tmtb_result;
        data_out.fas_fon_result = fas_fon_result;
        data_out.fas_sem_result = fas_sem_result;

        data_out.diagcog = diagcog;

    end
    
    % Export all the participants or only healhty participants
    if param.export_all
        ids2include = ismember(data_out.id_meg, data_all.id_meg);
    else
        mask = mask_healthy & mask_age_thres & (mmse_ok==1);
        ids2include = ismember(data_out.id_meg, data_all.id_meg(mask));
    end

    eval([sheetname ' = data_out(ids2include,:);' ]);
   

    % Save each sheet to excel file
    % writetable(eval(sheetname), out_file, 'Sheet',sheetname);

end

