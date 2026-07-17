function [participants, apexp_all] = load_data(config)

% Loads the template.
template         = load ( config.template );
cortical_mask = ismember(template.grid.area,config.roi);


%% Load metadata to assign groups
participants = readtable(config.path.metadata, 'PreserveVariableNames', true );
participants.group = categorical (participants.group);
participants.group_merged = participants.group;

% Select participants from nemos
participants = participants(startsWith(participants.participant_id,'NEMOS'),:);

participants.group_merged = participants.group;
participants.group_merged(ismember(participants.group, ["MCIa","MCIm"])) = "MCIstable";
participants.group_merged(participants.converter == 1) = "MCIconv";
participants.group_merged = categorical(participants.group_merged);

%% List fooof files and match order with participants' metadata
files = dir(fullfile(config.path.fooofL1, config.path.patt));

% Extract participant_id and session from each file
file_ids = cellfun(@(x) strtok(x, '_'), {files.name}, 'UniformOutput', false)';

% Matches metadata with the right data
participant_keys = strcat(string(participants.participant_id), "_", string(participants.session));
file_keys        = strcat(string(file_ids), "_L1");

% Keep only files present in participants table, preserving participants order
[is_included, file_order] = ismember(participant_keys, file_keys);

participants = participants(is_included, :);
files        = files(file_order(is_included));

% Safety check
ordered_file_ids = cellfun(@(x) strtok(x, '_'), {files.name}, 'UniformOutput', false)';
assert(isequal(string(ordered_file_ids), string(participants.participant_id)), ...
    'Files and participants are not in the same order.');

%% Load aperiodic exponent data

apexp_all = nan(numel ( files ), numel(cortical_mask));

% Goes though each file.
for findex = 1: numel ( files )

    % Loads the fooof data.
    fooofdata          = load ( fullfile ( files (findex).folder, files ( findex ).name ) );
    apexp_all(findex,:) = fooofdata.apexp_clean;

end


end