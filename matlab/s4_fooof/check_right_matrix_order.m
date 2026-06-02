% File path

files = dir('C:\Users\Cristina\megtusalen\L1\data\sources\fooof_py\*nii.gz');
% files = dir('C:\Users\Cristina\megtusalen\L1\data\sources\fooof_py\*.mat');

for i=1:length(files)
    fname = fullfile(files(i).folder, files(i).name);
    subj = split(files(i).name, '_');
    subj = subj{1};
    img = niftiread(fname);
    % load(fname,'apexp_clean');
    % img = apexp_clean;

    nsources =  sum(~isnan(img(:)));
    if nsources < 1089
        fprintf('%s Nsources: %d\n', subj, nsources)
    end

    % if find(~isnan(img),1) == 1008 
    %     % fprintf('%s ok\n',subj)
    % else
    %     fprintf('%s NOT ok\n',subj)
    % end
end