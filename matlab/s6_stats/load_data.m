function [participants, apexp_all] = load_data(config)

% Loads the template.
template         = load ( config.template );
cortical_mask = ismember(template.grid.area,config.roi);


%% Load metadata to assign groups
participants = readtable(config.path.metadata, 'PreserveVariableNames', true );
participants.group = categorical (participants.group);
participants.group_merged = participants.group;

% Recode values
participants.group_merged(ismember(participants.group, ["MCIa","MCIm"])) = "MCI";
participants.group_merged(participants.group == "CONV") = "AD";
participants.group_merged = categorical(participants.group_merged);


%% List fooof files and match order with participants' metadata
filesL1 = dir(fullfile(config.path.fooofL1, config.path.patt));
filesL2 = dir(fullfile(config.path.fooofL2, config.path.patt));
files = [filesL1; filesL2];

% Extract participant_id and session from each file
file_ids = cellfun(@(x) strtok(x, '_'), {files.name}, 'UniformOutput', false)';
file_session = strings(numel(files), 1);

for i = 1:numel(files)
    if contains(files(i).folder, [filesep 'L1' filesep])
        file_session(i) = "L1";
    elseif contains(files(i).folder, [filesep 'L2' filesep])
        file_session(i) = "L2";
    end
end

% Matches metadata with the right data
participant_keys = strcat(string(participants.participant_id), "_", string(participants.session));
file_keys        = strcat(string(file_ids), "_", file_session);

% Keep only files present in participants table, preserving participants order
[is_included, file_order] = ismember(participant_keys, file_keys);

participants = participants(is_included, :);
files        = files(file_order(is_included));

% Safety check
ordered_file_ids = cellfun(@(x) strtok(x, '_'), {files.name}, 'UniformOutput', false)';
assert(isequal(string(ordered_file_ids), string(participants.participant_id)), ...
    'Files and participants are not in the same order.');

%% Load aperiodic exponent data and deal with nan values
% Impute apexp to rois which are missing some apexp value. Fill missing values for that roi with
% the mean of that roi. If all values of a roi
% are missing the participant will be discarded from the statistical
% analysis.

% List all rois and their size
% cumsum = 0;
% for iroi = 1 : numel(config.roi)
%     roi_mask = template.grid.area == config.roi(iroi);
%     fprintf('Roi %-2d | size %-2d | %s \n', iroi, sum(roi_mask), template.atlas.name{iroi})
%     cumsum = cumsum + sum(roi_mask);
% end

apexp_all = nan(numel ( files ), numel(cortical_mask));

% discard_subjects = [];

% Goes though each file.
for findex = 1: numel ( files )

    % Loads the fooof data.
    fooofdata          = load ( fullfile ( files (findex).folder, files ( findex ).name ) );
    apexp = fooofdata.apexp_clean;

    % for iroi = 1:numel(config.roi)
    % 
    %     roi_mask = template.grid.area == config.roi(iroi);
    %     apexp_roi = apexp(roi_mask);
    % 
    %     % Discard subjects who are missing a whole roi
    %     if all(isnan(apexp_roi))
    %         % warning('All nans in findex %-3d | roi %-2d | roi size %-2d',findex, iroi, sum(roi_mask));
    %         discard_subjects = [discard_subjects findex];
    %         break
    %     end
    % 
    %     % Check the percentage of sources of the roi that are missing. 
    %     if any(isnan(apexp_roi))
    % 
    %         nanpos = isnan(apexp_roi);
    %         pernan = (sum(nanpos) / sum(roi_mask)) * 100;
    %         % warning('findex %-3d | roi %-2d | roi size %-2d | percentage nan %-5.1f',findex, iroi, sum(roi_mask), pernan);
    % 
    %         % If more than 50% of positions missing discard subject.
    %         if pernan > config.threshnanrois 
    %             % warning('Participant will be discarded: findex %-3d | roi %-2d | roi size %-2d | percentage nan %-5.1f',findex, iroi, sum(roi_mask), pernan);
    %             discard_subjects = [discard_subjects findex];
    %             break
    %         else
    % 
    %             % Impute aperiodic exponent with the mean of the roi
    %             mean_apexp = mean(apexp(roi_mask),'omitnan');
    %             idx_roi = find(roi_mask);
    %             apexp(idx_roi(nanpos)) = mean_apexp;
    % 
    %         end
    % 
    %     end
    % 
    % end

    apexp_all(findex,:) = apexp;

end
% discard_subjects = unique(discard_subjects);
% subject_mask = true(height(participants),1);
% subject_mask(discard_subjects) = false;
% 
% % Discard subjects
% participants = participants(subject_mask,:);
% apexp_all = apexp_all(subject_mask,:);

end