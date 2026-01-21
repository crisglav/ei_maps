% Define the path
path = 'C:\Users\Cristina\C3N Dropbox\Proyectos\Megtusalen\rawdata\meg_OA_fam';
path_out = 'C:\Users\Cristina\C3N Dropbox\Usuarios\Cristina Gil\metadata';

% Get directory listing
files_drop = dir(path);

% Remove '.' and '..' (and folders, if you only want files)
files_drop = files_drop(~[files_drop.isdir]);

% Extract filenames
file_names = {files_drop.name}';

% % Define output text file
% output_file = fullfile(path_out, 'meg_OA_fam_dropbox_list.txt');
% 
% % Write filenames to text file
% fid = fopen(output_file, 'w');
% fprintf(fid, '%s\n', file_names{:});
% fclose(fid);
% 
% disp(['Saved file list to: ' output_file]);

%% match regex
config.path.regexp = '^fam_([0-9]{3})_([A-Za-z]+)_([A-Za-z0-9]+)\.fif$';

% Gets the list of filenames.
hits = file_names;

% Search for the regular expression in the file names.
meta     = regexp ( hits, config.path.regexp, 'tokens' );

% Flatten the nested cell structure to get just the numbers
subject_numbers = cellfun(@(x) x{1}{1}, meta, 'UniformOutput', false);

disp(subject_numbers);

% Get unique numbers
unique_numbers = unique(subject_numbers);


% Removes the files that do not match the regular expression.
hits     = hits ( ~cellfun ( @isempty, meta ) );
meta     = meta ( ~cellfun ( @isempty, meta ) );