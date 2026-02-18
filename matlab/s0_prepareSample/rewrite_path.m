% Megtusalen taskinfo.fileinfo.dataset does not match the .fif names stored
% in dropbox

addpath ( fullfile ( '..' , 'functions') );

config = load_config ( 'config_s1.json' );

config.path.segments = fullfile ( config.path.project_root, 'data', 'segments' );
config.path.tsss = fullfile ( config.path.project_root, 'data', 'tsss');
config.path.patt = '*.mat';

% List tsss files
files_tsss = dir ( fullfile ( config.path.tsss , '*.fif' ) );
files_tsss = { files_tsss.name };

% Load table with equivalence names
participants = readtable( fullfile ('..', '..', 'data', 'participant_sample.xlsx'));
id_meg = [participants.id_meg ];
id_dropbox = [participants.id_dropbox ];

% Gets the list of task files.
files = dir ( fullfile ( config.path.segments, config.path.patt ) );

% Goes through each subject and task.
for sindex = 1: numel ( files )
    
    % Gets the current file name.
    filename            = files ( sindex ).name;
    filename            = fullfile ( config.path.segments, filename );
    taskinfo = load(filename);
    
    % Extract file name
    [~, name, ~] = fileparts(filename);
    subid = strsplit(name,'_');
    subid = subid{1};

    % Look up in the table the name
    idx = find(startsWith(id_dropbox, subid),1);

    % Look up in the tsss files the one that starts with the old index
    oldid = id_meg(idx);
    idx = find(startsWith(files_tsss,oldid));
    newfile = fullfile ( config.path.tsss, files_tsss{idx} );

    % Update the taskinfo struct
    fprintf(1, 'Updating the taskinfo.dataset struct to %s\n', newfile );
    taskinfo.fileinfo.dataset = newfile;
    save ( '-v6', filename, '-struct', 'taskinfo' )

end
