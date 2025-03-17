% Selecciona participantes sanos y supersanos de Megtusalenbasandose en los tests
% neuropsicologicos comunes a los tres proyectos (NEMOS, UMEG, Familiares)
%
% Lucía Hernández, C3N, 2024
clear all
close all
clc

%% open all sheets
data_all = readtable('../data/supermegtusalen_global_vOct2024.xlsx');

%% Modifiable parameters
param.unimp_d = [1, 2, 7, 8, 9]; %los diagnosticos "sanos"
param.age = 50;
param.mmse = 26;
param.mmse_age = 75;
param.escol = [8, 17]; % thresholds años de escolarización
param.escol_diginv = [9, 17]; % 

ageranks = [50 56; 57 59; 60 62; 63 65; 66 68; 69 71; 72 74; 75 77; 78 80; 81 90];
time_a = [101; 109; 119; 111; 124; 157; 159; 159; 160; 159];
time_b = [380; 380; 380; 401; 317; 420; 448; 461; 428; 428];
fassem = [13, 12, 11, 11, 11, 10, 10, 9, 8, 9];

%% Filter BBDD 
data_subsamp = data_all(data_all.diag == param.unimp_d(1) | data_all.diag == param.unimp_d(2) |...
    data_all.diag == param.unimp_d(3) | data_all.diag == param.unimp_d(4) |...
    data_all.diag == param.unimp_d(5), :); 

data_subsamp = data_subsamp(data_subsamp.age >= param.age & ~isnan(data_subsamp.age), :);

%MMSE adj
for isuj = 1:size(data_subsamp,1)
    
    % If the chronological age is equal or higher than the MMSE age
    if data_subsamp.age(isuj) >= param.mmse_age
            % If no data about education years use the MMSE age
        if isnan(data_subsamp.a_os_esc(isuj))
            data_subsamp.mmseadjL(isuj) = data_subsamp.MMSE(isuj);
            % Education years lower or equal than 8, increase MMSE by 2
        elseif data_subsamp.a_os_esc(isuj) <= param.escol(1)
            data_subsamp.mmseadjL(isuj) = data_subsamp.MMSE(isuj)+2;
            % Education years between 9 and 17, increase MMSE by 1
        elseif data_subsamp.a_os_esc(isuj) > param.escol(1) && data_subsamp.a_os_esc(isuj) <= param.escol(2) %%HABLAR ESTO LUCIA
            data_subsamp.mmseadjL(isuj) = data_subsamp.MMSE(isuj)+1;
            % 18 or more education years, use MMSE age
        elseif data_subsamp.a_os_esc(isuj) >param.escol(2)
            data_subsamp.mmseadjL(isuj) = data_subsamp.MMSE(isuj);
        end

    % If the chronological age is lower than the MMSE age    
    else 
        % If no data about education years use the MMSE age
        if isnan(data_subsamp.a_os_esc(isuj))
            data_subsamp.mmseadjL(isuj) = data_subsamp.MMSE(isuj);
        % Education years lower or equal than 8, increase MMSE by 1    
        elseif data_subsamp.a_os_esc(isuj) <= param.escol(1)
            data_subsamp.mmseadjL(isuj) = data_subsamp.MMSE(isuj)+1;
        % Education years between 9 and 17, use MMSE age    
        elseif data_subsamp.a_os_esc(isuj) > param.escol(1) & data_subsamp.a_os_esc(isuj) <= param.escol(2) 
            data_subsamp.mmseadjL(isuj) = data_subsamp.MMSE(isuj);
        % 18 or more education years, decrease MMSE one year  
        elseif data_subsamp.a_os_esc(isuj) >param.escol(2)
            data_subsamp.mmseadjL(isuj) = data_subsamp.MMSE(isuj)-1;
         end
    end 
    
    if data_subsamp.mmseadjL(isuj) > 30
        data_subsamp.mmseadjL(isuj) = 30;
    end 
end 
fprintf('\n %d subjects in sample, including MMSE nan and under 26 \n', size(data_subsamp,1))
data_subsamp = data_subsamp(data_subsamp.mmseadjL >= param.mmse & ~isnan(data_subsamp.mmseadjL >= param.mmse), :); 
fprintf('\n %d subjects in sample \n', size(data_subsamp,1))

%% Var adjustment
% Mem log
healthy.mem_log_uni_inm = nan(size(data_subsamp,1),1);
for isuj = 1:size(data_subsamp,1)
    if data_subsamp.age(isuj) >= 50 && data_subsamp.age(isuj) < 55 && data_subsamp.mem_log_uni_inm(isuj) >= 20
        healthy.mem_log_uni_inm(isuj) = 1;
    elseif data_subsamp.age(isuj) >= 50 && data_subsamp.age(isuj) < 55 && data_subsamp.mem_log_uni_inm(isuj) < 20
        healthy.mem_log_uni_inm(isuj) = 9;
        
    elseif data_subsamp.age(isuj) >= 55 && data_subsamp.age(isuj) < 66 && data_subsamp.mem_log_uni_inm(isuj) >= 15
        healthy.mem_log_uni_inm(isuj) = 1;
    elseif data_subsamp.age(isuj) >= 55 && data_subsamp.age(isuj) < 66 && data_subsamp.mem_log_uni_inm(isuj) < 15
        healthy.mem_log_uni_inm(isuj) = 9;

    elseif data_subsamp.age(isuj) >= 66 && data_subsamp.age(isuj) < 74 && data_subsamp.mem_log_uni_inm(isuj) >= 11
        healthy.mem_log_uni_inm(isuj) = 1;
    elseif data_subsamp.age(isuj) >= 66 && data_subsamp.age(isuj) < 74 && data_subsamp.mem_log_uni_inm(isuj) < 11
        healthy.mem_log_uni_inm(isuj) = 9;
    
    elseif data_subsamp.age(isuj) >= 74 && data_subsamp.mem_log_uni_inm(isuj) >= 8
        healthy.mem_log_uni_inm(isuj) = 1;
    elseif data_subsamp.age(isuj) >= 74 && data_subsamp.mem_log_uni_inm(isuj) < 8
        healthy.mem_log_uni_inm(isuj) = 9;
        
    else warning('error in subject %s', data_subsamp.id_proj{isuj})
    end 
end 
fprintf('\n %d healthy subjects in mem log uni inm \n', sum(healthy.mem_log_uni_inm == 1))
fprintf('\n %d patholog subjects in mem log uni inm \n', sum(healthy.mem_log_uni_inm == 9))
fprintf('\n %d nan subjects in mem log uni inm \n', sum(isnan(healthy.mem_log_uni_inm)))

healthy.mem_log_uni_dem = nan(size(data_subsamp,1),1);
for isuj = 1:size(data_subsamp,1)
    if data_subsamp.age(isuj) >= 50 && data_subsamp.age(isuj) < 55 && data_subsamp.mem_log_uni_dem(isuj) >= 9
        healthy.mem_log_uni_dem(isuj) = 1;
    elseif data_subsamp.age(isuj) >= 50 && data_subsamp.age(isuj) < 55 && data_subsamp.mem_log_uni_dem(isuj) < 9
        healthy.mem_log_uni_dem(isuj) = 9;
        
    elseif data_subsamp.age(isuj) >= 55 && data_subsamp.age(isuj) < 66 && data_subsamp.mem_log_uni_dem(isuj) >= 6
        healthy.mem_log_uni_dem(isuj) = 1;
    elseif data_subsamp.age(isuj) >= 55 && data_subsamp.age(isuj) < 66 && data_subsamp.mem_log_uni_dem(isuj) < 6
        healthy.mem_log_uni_dem(isuj) = 9;

    elseif data_subsamp.age(isuj) >= 66 && data_subsamp.age(isuj) < 74 && data_subsamp.mem_log_uni_dem(isuj) >= 2
        healthy.mem_log_uni_dem(isuj) = 1;
    elseif data_subsamp.age(isuj) >= 66 && data_subsamp.age(isuj) < 74 && data_subsamp.mem_log_uni_dem(isuj) < 2
        healthy.mem_log_uni_dem(isuj) = 9;
    
    elseif data_subsamp.age(isuj) >= 74 && data_subsamp.mem_log_uni_dem(isuj) >= 1
        healthy.mem_log_uni_dem(isuj) = 1;
    elseif data_subsamp.age(isuj) >= 74 && data_subsamp.mem_log_uni_dem(isuj) < 1
        healthy.mem_log_uni_dem(isuj) = 9;
        
    else warning('error in subject %s', data_subsamp.id_proj{isuj})
    end 
end 
fprintf('\n %d healthy subjects in mem log uni dem \n', sum(healthy.mem_log_uni_dem == 1))
fprintf('\n %d patholog subjects in mem log uni dem \n', sum(healthy.mem_log_uni_dem == 9))
fprintf('\n %d nan subjects in mem log uni dem \n', sum(isnan(healthy.mem_log_uni_dem)))

% Dig directos
for isuj = 1:size(data_subsamp,1)
    if data_subsamp.a_os_esc(isuj) <= param.escol(1)
        data_subsamp.dig_direcL(isuj) = data_subsamp.dig_direc(isuj) + 1;
    elseif data_subsamp.a_os_esc(isuj) > param.escol(1) && data_subsamp.a_os_esc(isuj) < param.escol(2)
        data_subsamp.dig_direcL(isuj) = data_subsamp.dig_direc(isuj);
    elseif data_subsamp.a_os_esc(isuj) >= param.escol(2)
        data_subsamp.dig_direcL(isuj) = data_subsamp.dig_direc(isuj) - 1;
    elseif isnan(data_subsamp.a_os_esc(isuj))
        data_subsamp.dig_direcL(isuj) = data_subsamp.dig_direc(isuj);
    else warning('error in suj %s', id_meg{isuj})
    end 
end 
healthy.dig_direc = nan(size(data_subsamp,1),1);
healthy.dig_direc(data_subsamp.dig_direcL >= 4, :) = 1; 
healthy.dig_direc(data_subsamp.dig_direcL < 4, :) = 9; 

fprintf('\n %d healthy subjects in dig direc \n', sum(healthy.dig_direc == 1))
fprintf('\n %d patholog subjects in dig direc  \n', sum(healthy.dig_direc == 9))
fprintf('\n %d nan subjects in dig direc  \n', sum(isnan(healthy.dig_direc)))


% Dig inversos
for isuj = 1:size(data_subsamp,1)
    if data_subsamp.a_os_esc(isuj) <= param.escol_diginv(1)
        data_subsamp.dig_invL(isuj) = data_subsamp.dig_inv(isuj) + 1;
    elseif data_subsamp.a_os_esc(isuj) > param.escol_diginv(1) & data_subsamp.a_os_esc(isuj) < param.escol_diginv(2)
        data_subsamp.dig_invL(isuj) = data_subsamp.dig_inv(isuj);
    elseif data_subsamp.a_os_esc(isuj) >= param.escol_diginv(2)
        data_subsamp.dig_invL(isuj) = data_subsamp.dig_inv(isuj) - 1;
    elseif isnan(data_subsamp.a_os_esc(isuj))
        data_subsamp.dig_invL(isuj) = data_subsamp.dig_inv(isuj);
    else warning('error in suj %s', data_subsamp.id_meg{isuj})
    end 
end 
healthy.dig_inv = nan(size(data_subsamp,1),1);

for isuj = 1:size(data_subsamp,1)
    if data_subsamp.age(isuj) >= 50 & data_subsamp.age(isuj) <= 56 & data_subsamp.dig_invL(isuj) >=3
        healthy.dig_inv(isuj) = 1;
    elseif data_subsamp.age(isuj) >= 50 & data_subsamp.age(isuj) <= 56 & data_subsamp.dig_invL(isuj) <3
        healthy.dig_inv(isuj) = 9;
        
    elseif data_subsamp.age(isuj)> 56 & data_subsamp.dig_invL(isuj) >= 2
        healthy.dig_inv(isuj) = 1;
    elseif data_subsamp.age(isuj)> 56 & data_subsamp.dig_invL(isuj) < 2
        healthy.dig_inv(isuj) = 9;
    else warning('error in suj %s', data_subsamp.id_meg{isuj})
    end 
end
fprintf('\n %d healthy subjects in dig inv \n', sum(healthy.dig_inv == 1))
fprintf('\n %d patholog subjects in dig inv  \n', sum(healthy.dig_inv == 9))
fprintf('\n %d nan subjects in dig inv  \n', sum(isnan(healthy.dig_inv)))

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
%% healthy sujs
% el criterio para considerar patológico a algún sujeto es que tengan al
% menos dos 9s; que tengan mal dos pruebas. Si tienen NaN en alguna prueba,
% siendo que el criterio es que entre 3 y 9 tests, tener dos es lo
% considerado patológico, mantenemos el corte. Siendo así, >= 18 es 9 en
% healthy.all
no_neuro_lucia = nan(size(data_subsamp,1),1);
healthy.all = nan(size(data_subsamp,1),1);
for isuj = 1:size(data_subsamp,1)
    sum_all = nansum([healthy.dig_direc(isuj), healthy.dig_inv(isuj), healthy.fas_fon(isuj), healthy.fas_sem(isuj),...
        healthy.mem_log_uni_dem(isuj), healthy.mem_log_uni_inm(isuj),...
        healthy.tmta(isuj), healthy.tmtb(isuj)]);
    % sum_all
    if sum_all >= 3 && sum_all < 18
        healthy.all(isuj) = 1;
    elseif sum_all >= 18
        healthy.all(isuj) = 0;
    else
        fprintf('\n check subject (neuro is missed) %s \n', data_subsamp.id_meg{isuj})
        no_neuro_lucia(isuj) = 1;
    end
end 

healthy.superhealthy = healthy.dig_direc == 1 & healthy.dig_inv == 1 & healthy.fas_fon == 1 & healthy.fas_sem == 1 & ...
    healthy.mem_log_uni_dem == 1 & healthy.mem_log_uni_inm == 1 & healthy.tmta == 1 & healthy.tmtb == 1;

% Cristina
% Problemas: Hay que poner como condicion obligatoria que un participante tenga al
% menos 3 test neuropsicologicos validos. En el codigo de Lucia, si un
% participante tiene 2 tests hechos pero uno de ellos esta bien (un 9 y un
% 1), se clasifica como healthy (suma 10) cuando deberia ser nan. Los
% participantes con 2 tests hechos y los dos estan bien (suma 2) se
% clasifican como nan.

% Here 0 means that the test was correct, 1 that it was invalid
tests = [healthy.dig_direc, healthy.dig_inv, healthy.fas_fon, healthy.fas_sem,...
    healthy.mem_log_uni_dem, healthy.mem_log_uni_inm,...
    healthy.tmta, healthy.tmtb];
tests(tests == 1) = 0;
tests(tests == 9) = 1;

no_neuro = sum(~isnan(tests),2) < 3; % At least a participant must have 3 valid neuropyschological tests. Discrepancy with no_neuro_lucia
no_neuro_atall = all(isnan(tests),2); % Participants who did not have any neuropsychological test
no_healthy = nansum(tests,2) >= 2; % Participants who failed 2 or more neuropsychological tests
is_healthy = nansum(tests,2) < 2 & ~no_neuro; % Participants who have at least 3 valid neurpsychological tests and failed 0 or 1 tests.
superhealthy = all(tests == 0,2);
no_healthy_ids = data_subsamp.id_meg(no_healthy);
save('no_healthy_ids.mat', 'no_healthy_ids');
%% Prepare bbdd

% Cristina.
% Por defecto los sujetos sin suficientes datos neuro (menos de 3 tests validos) son asignados
% 0s en diag 0s en diagcog (no sanos) cuando pueden ser sanos pero simplemente no
% tener neuro. Mejor sustituir por las dos lineas de abajo.

% neurosys_diag = zeros(numel(data_subsamp.id_meg),1); 
neurosys_diag = nan(numel(data_subsamp.id_meg),1);
neurosys_diag(healthy.all==0) = 0;

neurosys_diag(healthy.all==1)       = 1;
neurosys_diag(healthy.superhealthy==1)  = 2;

%   metemos el diagnóstico cognitivo en la tabla
data_subsamp.diagcog = neurosys_diag;

%   Quitamos los sujetos sin neuro (no_neuro_at_all)
subswithoutneuro = {'U1165', 'N1141', 'N1159', 'N1184', 'F1057'};
data_subsamp(ismember(data_subsamp.id_meg, subswithoutneuro),:) = [];
%   muevo el nuevo diag al principio
data_subsamp = data_subsamp(:, [1:4 60 5:59]);

% megtusalen_healthy = data_subsamp(healthy.all==1,:);
% megtusalen_superhealthy = data_subsamp(healthy.superhealthy,:);

% writetable(data_subsamp, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'sample');


%%   Load extra data

sheetnames = {'megdata', 'genes', 'dtis', 'vols_aseg_lobes', 'vols_aparc', 'vols_exvivo', 'vols_wm', 'wmh', 'mri_reports'};

for isheet = 1:numel(sheetnames)
    %   Seleccionamos excel y sheet
    excelname       = 'excels/supermegtusalen_global_v2024_nans.xlsx';
    sheetname       = sheetnames{isheet};

    %   leemos excel
    opts            = detectImportOptions(excelname, 'Sheet', sheetname);
    opts.DataRange  = 'A2';
    exceldata       = readtable(excelname, opts, 'Sheet', sheetname);

    %   Ajustamos los códigos de data_subsamp
    subscodes   = exceldata.id_meg;
    ids2include = zeros(numel(data_subsamp.id_meg),1);
    for isub = 1:numel(data_subsamp.id_meg)
        idx = find(ismember(subscodes, data_subsamp.id_meg{isub}));
        if~isempty(idx)
            ids2include(isub) = idx;
        end
        clear idx
    end
    eval([sheetname ' = exceldata(ids2include,:);' ])
    clear ids2include subscodes isub exceldata
end


%% save ddbb
% writetable(megdata, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'megdata');
% writetable(genes, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'genes');
% writetable(dtis, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'dtis');
% writetable(vols_aseg_lobes, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'vols_aseg_lobes');
% writetable(vols_aparc, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'vols_aparc');
% writetable(vols_exvivo, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'vols_exvivo');
% writetable(vols_wm, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'vols_wm');
% writetable(wmh, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'wmh');
% writetable(mri_reports, 'megtusalen_cog_healthy_Nov2024.xlsx', 'Sheet', 'mri_reports');




