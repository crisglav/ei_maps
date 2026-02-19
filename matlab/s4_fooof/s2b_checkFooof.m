clc
clear
close all

addpath ( fullfile ( pwd , '..', 'functions' ) );

% Read config from json file
config = load_config( 'config_megtusalen.json') ;

addpath ( fullfile ( pwd , 'fooof_matlab' ) );
addpath ( fullfile ( pwd , 'script_tests' ) );
addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.figs.roi   = fullfile( config.path.project_root, 'figs', 'fooof','roi');
config.path.figs.apexp = fullfile( config.path.project_root, 'figs', 'fooof','apexp');
config.path.patt       = 'FAM-113*.mat';

% Action when the task have already been processed.
config.overwrite  = true;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% % Define rois in template_AAL template
% config.hipo = true;
% 
% if config.hipo
%     % AAL with hipocampus and parahipocampus.
%     roi = [ 1: 16 19: 20 23: 28 31: 40 43: 70 79: 90 ];
% else
%     % AAL without hipocampus and parahipocampus.
    roi = [ 1: 16 19: 20 23: 28 31: 36 43: 70 79: 90 ];
% end

% Load fs brain with AAL areas marked
srcatlas = load('FS average - myAAL.mat');

% Template
template = load('template_AAL.mat');
cortical = ismember(template.grid.area,roi);


% Load label map between AAL templates (MNI-foofeddata and fs brains)
map = readtable("map_aaal_labels.csv");

% % Creates and output folder, if needed.
% if ~exist ( config.path.figs, 'dir' ), mkdir ( config.path.figs ); end
% Creates and output folder, if needed.
if ~exist ( config.path.figs.roi, 'dir' ), mkdir ( config.path.figs.roi ); end
if ~exist ( config.path.figs.apexp, 'dir' ), mkdir ( config.path.figs.apexp ); end

% Gets the files list.
files = dir ( fullfile ( config.path.fooof, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )
    
    % Preload the data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ), 'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', fooofdata.subject, fooofdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, fooofdata.channel );

    if ~exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_fooof_sources.mat', fooofdata.subject, fooofdata.task, fooofdata.channel ) ), 'file' )
        fprintf ( 1, 'Fooof data was not calculated for this subject: %s.\n', msgtext );
        continue
    end

    fprintf ( 1, 'Working with %s.\n', msgtext );

    fprintf ( 1, '  Loading the data.\n' );

    % Load fooof data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ));
    
    % Modeled power spectrum
    fm = fooofdata.fm;

    % pow = nan(size(cortical,1),size(fm.power_spectrum,2));
    % pow(cortical,:) = fm.power_spectra;

    % Extract rois of the atlas
    cortical_idx = find(cortical);
    mask = zeros(size(cortical_idx));

    % Plot fooofed power spectrum at each roi
    for iRoi=1:length(roi)

        % Get all sources from this roi

        roi_mask = ismember(template.grid.area, roi(iRoi));
        roi_label = template.atlas.name{roi(iRoi)};
        roi_idx = find(roi_mask);

        [~,idx] = intersect(cortical_idx, roi_idx);
        mask(idx) = 1;

        fig = fm.plot('rois',logical(mask));

        % Fooof object
        % fm_roi = fm(iRoi).fooof;
        % fig = fm_roi.plot;
        ax = findobj(fig, 'Type', 'axes');
        title(ax, roi_label);
        outname = sprintf ( '%s_%s_%s_fooof_%d.png', fooofdata.subject, fooofdata.task, fooofdata.channel, iRoi );
        exportgraphics(ax,fullfile(config.path.figs.roi, outname));
        close(fig);
    end

    
    % % Extract aperiodic exponents in the available regions of the atlas fs
    % % brain
    % apexp = [ fooofdata.fm.apexp]';
    % mask = logical(map.match);
    % apexp = apexp(mask);
    % 
    % % Plot aperiodic exponents
    % plot_brain_hemispheres(apexp,srcatlas)
    % 
    % % Saves the figure.
    % print ( '-dpng', fullfile ( config.path.figs.apexp, sprintf ( '%s_%s_%s_w%s_r%s_%s_fooof.png', fooofdata.subject, fooofdata.task, fooofdata.channel, fooofdata.whitener, fooofdata.lambda, fooofdata.taper ) ) )
    % 
    close all

end


