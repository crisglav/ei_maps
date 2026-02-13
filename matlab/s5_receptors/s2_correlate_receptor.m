clc
clear
close all

addpath ( fullfile ( pwd , '..', 'functions' ) );

% Read config from json file
config = load_config( 'config_s5_receptors.json') ;

addpath ( fullfile ( '..' , 's4_fooof', 'fooof_matlab' ) );
% addpath ( fullfile ( pwd , 'script_tests' ) );
% addpath ( fullfile ( config.path.meeg_analysis , 'script', 'functions' ) );

% Sets the paths.
config.path.fooof      = fullfile( config.path.project_root, 'data', 'sources', 'fooof');
config.path.corr       = fullfile( config.path.project_root, 'data', 'receptor' );

config.path.patt       = '*fooof_sources.mat';

% Add fieldtrip to path
addpath ( config.path.ft_path )
ft_defaults

% Action when the task have already been processed.
config.overwrite  = true;

% % Define rois in template_AAL template
% config.hipo = true;
% 
% if config.hipo
%     % AAL with hipocampus and parahipocampus.
%     roi = [ 1: 16 19: 20 23: 28 31: 40 43: 70 79: 90 ];
% else
%     % AAL without hipocampus and parahipocampus.
%     roi = [ 1: 16 19: 20 23: 28 31: 36 43: 70 79: 90 ];
% end

% Load receptor map
config.template = 'template_receptors.mat';
template = load(config.template);

% Creates and output folder, if needed.
if ~exist ( config.path.corr, 'dir' ), mkdir ( config.path.corr ); end

% Gets the files list.
files = dir ( fullfile ( config.path.fooof, config.path.patt ) );

corrs = nan(1,length(files));
% Goes through all the files.
for findex = 1: numel ( files )
    
    % Preload the data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ), 'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

    % Gets the text of the message.
    msgtext          = sprintf ( 'subject ''%s'', task ''%s''', fooofdata.subject, fooofdata.task );
    msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, fooofdata.channel );

    if exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_w%s_r%s_%s_fooof.mat', fooofdata.subject, fooofdata.task, fooofdata.channel, fooofdata.whitener, fooofdata.lambda, fooofdata.taper ) ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring %s (Already calculated).\n', msgtext );
        continue
    end

    fprintf ( 1, 'Working with %s.\n', msgtext );

    fprintf ( 1, '  Loading the data.\n' );

    % Load fooof data
    fooofdata         = load ( fullfile ( config.path.fooof, files ( findex ).name ));
    
    % Aperiodic exponent
    apexp = fooofdata.apexp';

    % Extract receptor
    dubois = template.receptor.dubois;

    % Select only cortical rois
    cortical = find(~isnan(apexp));

    % Calculate spatial correlation between receptor and aperiodic exponent
    corrs(findex) = corr(dubois(cortical), apexp(cortical));

end

% save correlation to results
save(fullfile('..','..','results','dubois_corrs.mat'),'corrs');

% figure,
% scatter(1:length(files),corrs);
% 
% [h,p,ci,stats] = ttest(corrs);


% Restrict glutamate distribution only to cortical sources
template.grid.glu = template.receptor.dubois;
template.grid.glu(isnan(apexp)) = nan;

% Interpolate glutamate binding potential (in grid) to mri template for
% visualization
cfg = [];
cfg.parameter = 'glu';
cfg.interpmethod = 'nearest';
interp = ft_sourceinterpolate(cfg, template.grid, template.mri);

% Plot our template with receptor map overlying
cfg = [];
cfg.method        = 'ortho';
cfg.funparameter  = 'glu';
ft_sourceplot(cfg, interp);

% Interpolate aperiodic exponent (in grid) to mri template for
% visualization
template.grid.apexp = apexp;
cfg = [];
cfg.parameter = 'apexp';
cfg.interpmethod = 'nearest';
interp = ft_sourceinterpolate(cfg, template.grid, template.mri);

% Plot our template with receptor map overlying
cfg = [];
cfg.method        = 'ortho';
cfg.funparameter  = 'apexp';
cfg.funcolorlim   = [min(apexp), max(apexp)];
ft_sourceplot(cfg, interp);