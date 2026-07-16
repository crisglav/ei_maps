clc
clear
close all

% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );
addpath ( sprintf ( '%s/functions/',  pwd ) );

% Paths
config.path.ft_path = 'C:\Users\Cristina\repos\fieldtrip';
config.path.project_root = 'C:\Users\Cristina\megtusalen\L1';

% Sets the paths.
config.path.meg     = fullfile( config.path.project_root, 'data', 'segments');
config.path.beam    = fullfile( config.path.project_root, 'data', 'sources', 'lcmv');
config.path.vdata     = fullfile( config.path.project_root, 'data', 'sources', 'vdata');
config.path.patt     = 'FAM-001*.mat';

% Action when the task have already been processed.
config.overwrite  = true;

% Name of the beamformer filter to use.
config.beamformer = 'Broadband';

% AAL atlas and cortical rois
config.template = '../templates/template_AAL.mat';
config.roi = [1:40, 43:70, 79:90]';

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Loads the template.
template = load ( config.template );

% Creates and output folder, if needed.
if ~exist ( config.path.vdata, 'dir' ), mkdir ( config.path.vdata ); end

% Gets the list of subjects.
files    = dir ( fullfile ( config.path.beam, config.path.patt ) );

% Goes through each subject.
for file = 1: numel ( files )
    
    % Loads the MEG data and the beamformer information.
    filename         = files ( file ).name;
    [ ~, basename ]  = fileparts ( filename );
    
    beamformer       = load ( fullfile ( config.path.beam,  basename ), 'subject', 'task', 'stage', 'channel', 'whitener', 'lambda' );
    
    if exist ( fullfile ( config.path.vdata, sprintf ( '%s_%s_%s.mat', beamformer.subject, beamformer.task, beamformer.channel ) ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring subject ''%s'', task ''%s'', channel group ''%s'' (already calculated).\n', beamformer.subject, beamformer.task, beamformer.channel );
        continue
    end
    
    % Lists the MEG files.
    sensfile         = dir ( fullfile ( config.path.meg, sprintf ( '%s_%s%s*.mat',beamformer.subject, beamformer.task, beamformer.stage ) ) );
    
    if isempty ( sensfile )
        fprintf ( 1, 'Ignoring subject ''%s'', task ''%s'', channel group ''%s'' (no MEG data).\n', beamformer.subject, beamformer.task, beamformer.channel );
        continue
    end
    
    fprintf ( 1, 'Working on subject ''%s'', task ''%s'', channel group ''%s''.\n', beamformer.subject, beamformer.task, beamformer.channel );
    
    fprintf ( 1, '  Loading data.\n' );
    
    sensfile          = sensfile (1).name;
    
    sensdata         = myft_load ( fullfile ( config.path.meg, sensfile ) );
    beamformer       = load ( fullfile ( config.path.beam, basename ) );
    
    % Gets the number of padding samples of the data.
    padding          = round ( sensdata.trialinfo.trialpad (1) * sensdata.trialdata.fsample );
    
    
    % Keeps only the requested band.
    bandinfo         = beamformer.band;
    bandinfo         = bandinfo ( strcmpi ( { bandinfo.name }, config.beamformer ) );
    
    % Gets the beamformer information.
    source           = bandinfo.sources;
    filter           = cat ( 3, source.filter {:} );
    filter           = permute ( filter, [ 1 3 2 ] );
    
    % Gets the data dimensions.
    nori             = size ( filter, 1 );
    nsource          = size ( filter, 2 );
    
    % Reshapes the filter to allow matrix multiplication.
    % filter           = reshape ( filter, nori * nsource, [] );
    
    % Selects only the channels present in the beamformer filter.
    cfg              = [];
    cfg.channel      = source.label;
    cfg.trials       = 'all';
    
    trialdata        = ft_selectdata ( cfg, sensdata.trialdata );
    
    % Removes the padding.
    trialdata        = myft_rmpad ( trialdata, sensdata.trialinfo.trialpad );
    
    % Select cortical sources only
    cortical_mask = ismember(template.grid.area,config.roi);
    
    % Extract virtual channel data - direction of max power
    cfg = [];
    cfg.pos = source.pos(cortical_mask,:);
    cfg.method = 'svd'; % Combine orientations of the spatial filter
    vdata = ft_virtualchannel(cfg,trialdata,source);

    % Save it into bandinfo
    bandinfo.vdata = vdata;
    
    fprintf ( 1, '  Saving the virtual data.\n' );
    
    % Prepares the output.
    virtualdata          = [];
    virtualdata.subject  = beamformer.subject;
    virtualdata.task     = beamformer.task;
    virtualdata.channel  = beamformer.channel;
    virtualdata.whitener = beamformer.whitener;
    virtualdata.lambda   = beamformer.lambda;
    virtualdata.band     = bandinfo;
    
    % Saves the data.
    save ( '-v6', fullfile ( config.path.vdata, sprintf ( '%s_%s_%s_vdata', virtualdata.subject, virtualdata.task, virtualdata.channel ) ), '-struct', 'virtualdata' );
end
