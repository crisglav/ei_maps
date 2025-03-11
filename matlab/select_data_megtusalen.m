%% Comparison of Megtusalen data
%
% Cristina Gil Avila, 11/03/2025, C3N

clear all, close all
%% Load dataset versions (excels)
 
% Megtusalen_vJescab.xls (N=729, only baseline recordings)
megtusalen = readtable('../data/megtusalen_vJescab.xlsx');

% Discard longitudinal recordings (there is a 2 in the second position of ID_OBSERVACION)
id_jes = megtusalen.ID_OBSERVACION;
id_1 = cellfun(@(x) numel(x) >= 2 && x(2) == '1', id_jes);
megtusalen = megtusalen(id_1,:);

% Megtusalen_tesis_adri.xls (N=760)
megtusalen_adri = readtable('../data/megtusalen_tesis_adri_v2025.xlsx');
id_adri = megtusalen_adri.id_meg;

% supermegtusalen_global_v2024_nans.xls (N=760)
supermegtusalen = readtable('../data/supermegtusalen_global_v2024_nans.xlsx');

% Check if all recordings are baseline recordings
id_meg = supermegtusalen.id_meg;
id_1 = cellfun(@(x) numel(x) >= 2 && x(2) == '1', id_meg);
if all(id_1)
    fprintf('All recordings are baseline\n')
end

%% Participants comparisons between excel sheets

% Comparison of MEG ids included in Megtusalen_tesis_adri and supermegtusalen_global
% Both datasets contain the same individuals
sum(ismember(id_adri,id_meg))
sum(ismember(id_meg,id_adri))

% Comparison of MEG ids included in Megtusalen_vJescab and Megtusalen_tesis_adri
% All the members in Jesus' excel are present in Adri's excel
nin_jes = sum(ismember(id_jes, id_adri));

% Only 729 out of 760 members in Adris' excel are present in Jesus' excel
nin_adri = sum(ismember(id_adri, id_jes));

% 31 members in Adris' excel are not present in Jesus' excel
nout_adri = sum(~ismember(id_adri, id_jes));
out_adri = id_adri(~ismember(id_adri, id_jes));
megtusalen_adri(~ismember(id_adri, id_jes),:) % No data present on most of these individuals

% Conclusion: take supermegtusalen
%% List all the available raw files (fif) in the dropbox folder and compare them with the excel file
dropbox_path = 'C:\Users\Cristina\C3N Dropbox\Proyectos\Megtusalen\data\tsss';
fif = dir(fullfile(dropbox_path,'*.fif'));
fif_name = {fif.name};

id_fif = cellfun(@(x) x{1}, cellfun(@(y) strsplit(y, '_'), fif_name, 'UniformOutput', false), 'UniformOutput', false);

% Find unique participants
[id_fif_unique, ~, idx] = unique(id_fif);

% Identify elements that appear more than once
counts = accumarray(idx, 1);
duplicateElements = id_fif_unique(counts > 1);
duplicatePositions = ismember(id_fif, duplicateElements);

fif(duplicatePositions,:);


%% Find discrepancies between fif files and megtusalen excel data

% There are 2 out of 674 participants that have a fif file but do not
% appear in the megtusalen excel file
sum(ismember(id_fif_unique, id_jes));
id_fif_unique(~ismember(id_fif_unique, id_jes));

% There are 56 out of 729 participants that appear in the excel file but do not have a
% fif file.
sum(ismember(id_jes, id_fif_unique));
id_jes(~ismember(id_jes, id_fif_unique));


%% Separate by diagnosis

