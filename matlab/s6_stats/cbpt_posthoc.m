clc
clear
close all

% Adds the functions and templates to the path.
addpath ( fullfile ( '..', 'functions') );
addpath ( fullfile ( '..', 'templates') );
addpath ( fullfile ('functions'));

config.path.metadata       = fullfile( '..', '..', 'data', 'participants_real.xlsx');
config.path.ft_path = 'C:\Users\Cristina\repos\fieldtrip';

config.test = 'ancova';
config.regress_age = 'no';
config.path.stats     = fullfile( '..','..','results', 'stats', config.test, ['regress_age_' config.regress_age]);
config.contrast = 'SCDneg-SCDpos-MCIneg-MCI-AD';
config.groups = split(config.contrast, '-');

% Figs
config.path.figs      = fullfile( '..','..', 'figs', 'stats', 'posthoc');
if ~exist ( config.path.figs, 'dir' ), mkdir ( config.path.figs ), end

% Set fooof config.
config.path.project_root = 'C:\Users\Cristina\megtusalen';
config.path.fooofL1      = fullfile( config.path.project_root, 'L1', 'data', 'sources', 'fooof_py');
config.path.fooofL2      = fullfile(  config.path.project_root, 'L2', 'data', 'sources', 'fooof_py');
config.path.patt         = '*_sources.mat';
config.threshnanrois = 50;

% Load template
config.template        = 'template_AAL';
config.roi = [1:40, 43:70, 79:90]'; % Only cortical sources

template         = load ( config.template );
cortical_mask = ismember(template.grid.area,config.roi);

% Adds, if needed, the FieldTrip folder to the path.
addpath ( config.path.ft_path )
ft_defaults

% Load metadata and apexp data
[participants, apexp_all] = load_data(config);

% Impute nans or discard subjects
[participants, apexp_all, subject_mask] = deal_nans_apexp(config, participants, apexp_all);


% Load stats
files = dir ( fullfile ( config.path.stats, ['*_' config.contrast '.mat'] ) );
statdata = load ( fullfile ( config.path.stats, files ( 1 ).name ) );
stats      = statdata.stats;

% If no clusters continue
if all(isnan(stats.stat))
    error('No clusters.')
end

% If no significant clusters continue
if isempty(find(stats.prob<0.05, 1))
    error('No significant clusters.')
end

cluster = stats.mask > 0 & stats.prob <= 0.05;

% % In case there are more than one cluster do all this
% index      = any ( stats.mask, 1 );
% index      = cumsum ( index );
% index      = index > 0 & index <= max ( index );
% 
% cluster ( :, ~index ) = 0;
% cluster = mean ( cluster ( :, index ), 2 ) > 0.20;
% cluster = sum ( cluster ( :, index ), 2 );
% cluster = double ( cluster );


%% LME on the mean values of the cluster
% Extract all the values of the aperiodic exponent for the cluster and do
% the mean
apexp_cluster = mean(apexp_all(:,cluster),2);

% Lists only the valid data.
valid = ismember(participants.group_merged,config.groups);

% Data for the lme model
ap = apexp_cluster(valid,:);
ag = participants.age(valid);
gr = removecats(participants.group_merged(valid));

% Linear mixed model on the mean value of the cluster
tab = table(ap,ag,gr, 'VariableNames',{'apexp','age','group'});

% LME
model = fitlm(tab,'apexp~age*group');

w = linspace(min(ag),max(ag));

figure()
hold on,
scatter(ag(gr=='MCIneg'),ap(gr=='MCIneg'),'green','filled')
scatter(ag(gr=='MCI'),ap(gr=='MCI'),'blue','filled')
scatter(ag(gr=='AD'),ap(gr=='AD'),'red','filled')
scatter(ag(gr=='SCDneg'),ap(gr=='SCDneg'),'yellow','filled')
scatter(ag(gr=='SCDpos'),ap(gr=='SCDpos'),'magenta','filled')


% figure()
% gscatter(ag,ap,gr,'bgr','x.o')
line(w,feval(model,w,'MCIneg'),'Color','green','LineWidth',2)
line(w,feval(model,w,'MCI'),'Color','blue','LineWidth',2)
line(w,feval(model,w,'AD'),'Color','red','LineWidth',2)

line(w,feval(model,w,'SCDpos'),'Color','magenta','LineWidth',2)
line(w,feval(model,w,'SCDneg'),'Color','yellow','LineWidth',2)

legend({'MCIneg','MCI','AD','SCDneg','SCDpos'})
xlabel('Age')
ylabel('Avg aperiodic exponent at significant cluster')


%% LME per roi
clear model

% Find all the rois that belong to the cluster
statrois = unique(template.grid.area(cluster));
model.roi_name = [];
model.lm = [];

rsquared = nan(1,length(statrois));
coeff = nan(6,4,length(statrois));

for iroi =1: length(statrois)

    roi = statrois(iroi);
    roi_mask = template.grid.area == roi;
    roi_name = template.atlas.name{roi};
    % disp(roi_name)

    roi_cluster = find(roi_mask & cluster);

    % % Sanity check, paint this roi
    % % Interpolates the stats data to the surface.
    % cfg           = [];
    % cfg.parameter = { 'mask' 'stat' };
    % cfg.method    = 'nearest';
    % cfg.maxdist   = 0.01;
    % 
    % srcmodel = [];
    % srcmodel.dim = stats.dim;
    % srcmodel.pos = stats.pos;
    % srcmodel.inside = stats.inside;
    % srcmodel.dimord = stats.dimord;
    % srcmodel.unit = stats.unit;
    % srcmodel.stat = double(stats.inside);
    % srcmodel.mask = roi_mask;
    % 
    % statssurfl    = my_grid2surf ( cfg, srcmodel, 'surface_white_left.mat',  'surface_inflated_left_caret.mat' );
    % statssurfr    = my_grid2surf ( cfg, srcmodel, 'surface_white_right.mat', 'surface_inflated_right_caret.mat' );
    % 
    % % Plots the stats in the brain surface.
    % my_plotbrains ( statssurfl, statssurfr, roi_name );
    % 
    % srcmodel.mask = roi_mask & cluster;
    % srcmodel.stat = -double(stats.inside);
    % 
    % statssurfl    = my_grid2surf ( cfg, srcmodel, 'surface_white_left.mat',  'surface_inflated_left_caret.mat' );
    % statssurfr    = my_grid2surf ( cfg, srcmodel, 'surface_white_right.mat', 'surface_inflated_right_caret.mat' );
    % 
    % % Plots the stats in the brain surface.
    % my_plotbrains ( statssurfl, statssurfr, roi_name );


    apexp_cluster = mean(apexp_all(:,roi_cluster),2);

    % Data for the lme model
    ap = apexp_cluster(valid,:);
    ag = participants.age(valid);
    gr = removecats(participants.group_merged(valid));

    % Linear mixed model on the mean value of the cluster
    tab = table(ap,ag,gr, 'VariableNames',{'apexp','age','group'});

    % LME
    model(iroi).roi_name = roi_name;
    lm = fitlm(tab,'apexp~age*group');
    model(iroi).lm = lm;

    rsquared(iroi) = lm.Rsquared.Ordinary;
    coeff(:,:,iroi) = lm.Coefficients{:,:};

    % w = linspace(min(ag),max(ag));
    % 
    % figure()
    % hold on,
    % scatter(ag(gr=='MCIneg'),ap(gr=='MCIneg'),'green','filled')
    % scatter(ag(gr=='MCI'),ap(gr=='MCI'),'blue','filled')
    % scatter(ag(gr=='AD'),ap(gr=='AD'),'red','filled')
    % 
    % % figure()
    % % gscatter(ag,ap,gr,'bgr','x.o')
    % line(w,feval(lm,w,'MCIneg'),'Color','green','LineWidth',2)
    % line(w,feval(lm,w,'MCI'),'Color','blue','LineWidth',2)
    % line(w,feval(lm,w,'AD'),'Color','red','LineWidth',2)
    % 
    % legend({'MCIneg','MCI','AD'})
    % title(roi_name)
    % 
    % % Saves the figure.
    % print ( '-r150', '-dpng', fullfile ( config.path.figs, sprintf ( '%s.png', roi_name ) ) )
    % close



end
    
sig = coeff(:,4,:) < 0.05;
sig = squeeze(sig);

betas = squeeze(coeff(:,1,:));
betas(sig)