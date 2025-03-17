% Script that revises healthy control diagnosis based on neuropsychological
% assessments of Megtusalen data.
%
% - Input data: supermegtusalen_global_vOct2024.xlsx
% - Same excel file with corrected variables and variable diagcog that
% defines final healthy diagnosis:
%       0 - Participant not healthy
%       1 - Participant healthy
%       2 - Participant superhealthy (passed all tests)%
%
% Lucia Hernandez, C3N, 2024
% Cristina Gil, C3N, revised 17/03/2025

clear all
close all
clc

%% Load excel data
data_all = readtable('../data/supermegtusalen_global_vOct2024.xlsx');

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
param.escol = [8, 17];              % Education years

fprintf('%d subjects in original sample.\n', n);

% Create ouptut data
data_out = data_all;

%% Filter participans by controls
mask_healthy = any(data_all.diag == param.cn,2);
fprintf('%d healthy participants in original sample.\n', sum(mask_healthy));

%% Filter participants by existance of age data and age threshold
% Do not take into account participants younger than 50 or without
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

% Save variable to table
data_out.mmse_adj = mmse_adj;
data_out.mmse_extended = mmse_extended;
data_out.mmse_ok = mmse_ok;

fprintf('%d healhty participants with age data, older than %d, and with variable mmse_adj.\n', sum(mask_healthy & mask_age_thres & ~isnan(mmse_adj)), param.age);
fprintf('%d healthy participants with age data, older than %d, and with variable mmse_extended.\n', sum(mask_healthy & mask_age_thres & ~isnan(mmse_extended)), param.age);
fprintf('%d healthy participants with age data, older than %d, and with mmse_extended < 26.\n', sum(mask_healthy & mask_age_thres & (mmse_ok==1)), param.age);

%% Adjust the eight neuropsychological tests that were common to all Megtusalen participants and assess tests

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
        % No data
        mem_log_inm_result(isuj) = -1;
        continue;
    end

    % Save test results based on age thresholds specific to the test
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

    else
        % No data
        mem_log_inm_result(isuj) = -1;
    end 
end

fprintf('\n1. Immediate logic memory (memoria lógica inmediata) \n');
fprintf('%d healthy participants passed the test mem log uni inm \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & mem_log_inm_result == 1));
fprintf('%d healthy participants failed the test mem log uni inm \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & mem_log_inm_result == 0));
fprintf('%d healthy participants do not have the test mem log uni inm \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & mem_log_inm_result == -1));

% Save to table
data_out.mem_log_inm_result = mem_log_inm_result;

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
        % No data
        mem_log_dem_result(isuj) = -1;
        continue;
    end

    % Save test results based on age thresholds specific to the test
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

% Save to table
data_out.mem_log_dem_result = mem_log_dem_result;


% 3. Direct digit task (Dig directos). It measursers attention span.
% Variable to save tests results: 1 - passed test, 0 - failed test.
dig_dir_result = nan(n,1);

% First adjust variable by education years. If no data availabe for
% education years, use the original dig_dir score.
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
fprintf('%d healthy participants do not have the dig dir \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_dir_result == -1));

% Save to table
data_out.dig_dir_adj = dig_dir_adj;
data_out.dig_dir_result = dig_dir_result;


% 4. Inverse digit task (Dig inversos). It measures working memory.
% Variable to save tests results: 1 - passed test, 0 - failed test.
dig_inv_result = nan(n,1);

% First adjust variable by education years. If no data availabe for
% education years, use the original dig_inv score.
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

    if a_os_esc(isuj) <= param.escol(1)
        dig_inv_adj(isuj) = data_all.dig_inv(isuj) + 1;

    elseif a_os_esc(isuj) > param.escol(1) && a_os_esc(isuj) < param.escol(2)
        dig_inv_adj(isuj) = data_all.dig_inv(isuj);

    elseif a_os_esc(isuj) >= param.escol(2)
        dig_inv_adj(isuj) = data_all.dig_inv(isuj) - 1;

    end

end

% Assess test based on age ranks
for isuj = 1:n

    if age(isuj) >= 50 && age(isuj) <= 56
        if dig_inv_adj(isuj) >=3
            dig_inv_result = 1;
        else
            dig_inv_result = 0;
        end

    elseif age(isuj)> 56
        if dig_inv_adj(isuj) >= 2
            dig_inv_result = 1;
        else
            dig_inv_result = 0;
        end
    end
end

% Assess test
dig_dir_result(dig_dir_adj >= 4) = 1;
dig_dir_result(dig_dir_adj < 4) = 0;
dig_dir_result(dig_dir_adj == -1) = -1;

fprintf('\n3. Direct digit task \n');
fprintf('%d healthy participants passed the test dig dir \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_dir_result == 1));
fprintf('%d healthy participants failed the test dig dir \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_dir_result == 0));
fprintf('%d healthy participants do not have the dig dir \n', sum(mask_healthy & mask_age_thres & (mmse_ok==1) & dig_dir_result == -1));

% Save to table
data_out.dig_dir_adj = dig_dir_adj;
data_out.dig_dir_result = dig_dir_result;





% TMTA
healthy.tmta = nan(size(data_subsamp,1),1);
for isuj = 1:size(data_subsamp,1)
    for iage = 1:size(ageranks,1) 
        if data_subsamp.age(isuj) >= ageranks(iage, 1) & data_subsamp.age(isuj) <= ageranks(iage, 2) & data_subsamp.TMTa_T(isuj) <= time_a(iage)
            healthy.tmta(isuj) = 1;
        elseif data_subsamp.age(isuj) >= ageranks(iage, 1) & data_subsamp.age(isuj) <= ageranks(iage, 2) & data_subsamp.TMTa_T(isuj) > time_a(iage)
            healthy.tmta(isuj) = 9;
        end 
    end 
end
fprintf('\n %d healthy subjects in tmta \n', sum(healthy.tmta == 1))
fprintf('\n %d patholog subjects in tmta  \n', sum(healthy.tmta == 9))
fprintf('\n %d nan subjects in tmta \n', sum(isnan(healthy.tmta)))

% TMTB
healthy.tmtb = nan(size(data_subsamp,1),1);
for isuj = 1:size(data_subsamp,1)
    for iage = 1:size(ageranks,1) 
        if data_subsamp.age(isuj) >= ageranks(iage, 1) & data_subsamp.age(isuj) <= ageranks(iage, 2) & data_subsamp.TMTb_T(isuj) <= time_b(iage)
            healthy.tmtb(isuj) = 1;
        elseif data_subsamp.age(isuj) >= ageranks(iage, 1) & data_subsamp.age(isuj) <= ageranks(iage, 2) & data_subsamp.TMTb_T(isuj) > time_b(iage)
            healthy.tmtb(isuj) = 9;
        end 
    end 
end
fprintf('\n %d healthy subjects in tmtb \n', sum(healthy.tmtb == 1))
fprintf('\n %d patholog subjects in tmtb  \n', sum(healthy.tmtb == 9))
fprintf('\n %d nan subjects in tmtb \n', sum(isnan(healthy.tmtb)))

%FAS fon
healthy.fas_fon = nan(size(data_subsamp,1),1);
for isuj = 1:size(data_subsamp,1)
    if not(isnan(data_subsamp.sumFAS(isuj)))
        fon = data_subsamp.sumFAS(isuj);
        if data_subsamp.age(isuj) < 60 & data_subsamp.a_os_esc(isuj) < 13 & fon >= 27.55
            healthy.fas_fon(isuj) = 1;
        elseif data_subsamp.age(isuj) < 60 & data_subsamp.a_os_esc(isuj) < 13 & fon < 27.55
            healthy.fas_fon(isuj) = 9;
        elseif data_subsamp.age(isuj) >= 60 & data_subsamp.a_os_esc(isuj) < 13 & fon >=10.3
            healthy.fas_fon(isuj) = 1;
        elseif data_subsamp.age(isuj) >= 60 & data_subsamp.a_os_esc(isuj) < 13 & fon <10.3
            healthy.fas_fon(isuj) = 9;
        elseif data_subsamp.a_os_esc(isuj) >= 13 & fon >= 29.5
            healthy.fas_fon(isuj) = 1;
        elseif data_subsamp.a_os_esc(isuj) >= 13 & fon < 29.5
            healthy.fas_fon(isuj) = 9;
        elseif isnan(data_subsamp.a_os_esc(isuj)) & data_subsamp.age(isuj) < 60 & fon >= 27.55
            healthy.fas_fon(isuj) = 1;
        elseif isnan(data_subsamp.a_os_esc(isuj)) & data_subsamp.age(isuj) < 60 & fon < 27.55
            healthy.fas_fon(isuj) = 9;
        elseif isnan(data_subsamp.a_os_esc(isuj)) & data_subsamp.age(isuj) >= 60 & fon >= 10.3
            healthy.fas_fon(isuj) = 1;
        elseif isnan(data_subsamp.a_os_esc(isuj)) & data_subsamp.age(isuj) >= 60 & fon < 10.3
            healthy.fas_fon(isuj) = 9;

        end
    else
        warning('subject %s has nan in fasfon, check', data_subsamp.id_meg{isuj})
    end 
end 
fprintf('\n %d healthy subjects in fasfon \n', sum(healthy.fas_fon == 1))
fprintf('\n %d patholog subjects in fasfon  \n', sum(healthy.fas_fon == 9))
fprintf('\n %d nan subjects in fasfon \n', sum(isnan(healthy.fas_fon)))

% fas sem
healthy.fas_sem = nan(size(data_subsamp,1),1);
for isuj = 1:size(data_subsamp,1)
    if not(isnan(data_subsamp.animales(isuj))) & not(isnan(data_subsamp.age(isuj)))
        for iage = 1:size(ageranks,1)
            if data_subsamp.age(isuj) >= ageranks(iage, 1) & data_subsamp.age(isuj) <= ageranks(iage, 2)...
                    & data_subsamp.animales(isuj) >= fassem(iage)
                healthy.fas_sem(isuj) = 1;
            elseif data_subsamp.age(isuj) >= ageranks(iage, 1) & data_subsamp.age(isuj) <= ageranks(iage, 2)...
                    & data_subsamp.animales(isuj) < fassem(iage)
                healthy.fas_sem(isuj) = 9;
            end
        end
    else
        warning ('subject %s has nan in age and/or animals', data_subsamp.id_meg{isuj})
    end
end
fprintf('\n %d healthy subjects in fassem \n', sum(healthy.fas_sem == 1))
fprintf('\n %d patholog subjects in fassem  \n', sum(healthy.fas_sem == 9))
fprintf('\n %d nan subjects in fassem \n', sum(isnan(healthy.fas_sem)))