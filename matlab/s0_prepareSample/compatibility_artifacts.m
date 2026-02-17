% Rewrite segments info for megtusalen bids


config = [];
config.path.project_root = 'C:\Users\Cristina\megtusalen_bids';

sub = 126;

config.path.segments = fullfile ( config.path.project_root, 'derivatives', ['sub-' num2str(sub)] , 'segments' );
config.path.tsss = fullfile ( config.path.project_root, ['sub-' num2str(sub)], 'ses-1', 'meg');
config.path.patt = 'NEMOS*.mat';

files_tsss = dir ( fullfile (config.path.tsss, '*.fif'));

% Dir segments
files = dir ( fullfile (config.path.segments, config.path.patt));

% Gets the current file name.
% for sindex = 1: numel ( files )

sindex = 1;

    filename            = files ( sindex ).name;
    filename            = fullfile ( config.path.segments, filename );
    
    % Loads the current task information.
    taskinfo            = load ( filename );

    % Location to bids file


    % Update dataset with bids.fif
    taskinfo.fileinfo.dataset = fullfile (files_tsss.folder, files_tsss.name);

    % Save taskinfo
    save(filename, '-struct', 'taskinfo');

% end