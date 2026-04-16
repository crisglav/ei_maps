clc
clear
close all

% Adds general functions to the path.
addpath ( fullfile ( '..', 'functions') );

% Adds fooof functions to the path
addpath ( 'fooof_matlab' );

% Adds template folders to the path
addpath ( fullfile ( '..', 'templates') );

% Read config from json file
config = load_config( fullfile ('..', 'config_megtusalen.json' ) );

config.svd = true;
config.avg = true;
config.overwrite = true;

% Adds, if needed, the FieldTrip folder to the path.
myft_path ( config.path.ft_path )

% Loads AAL template
template = load ( 'template_AAL.mat' );
% Gets the number of rois.
nrois   = numel ( template.atlas.name );

sessions = {'L1','L2'};

% Goes through each session
for ses = 1: numel (sessions)

    % Sets the paths.
    config.path.pow     = fullfile( config.path.project_root, sessions{ses}, 'data', 'sources', 'power');
    config.path.fooof   = fullfile( config.path.project_root, sessions{ses}, 'data', 'sources', 'fooof');
    config.path.apexp   = fullfile( config.path.project_root, sessions{ses}, 'data', 'sources', 'apexp');
    config.path.log     = fullfile( config.path.project_root, sessions{ses}, 'logs');
    config.path.patt    = '*.mat';

    % Creates and output folder, if needed.
    if ~exist ( config.path.pow, 'dir' ), mkdir ( config.path.pow ); end

    % Creates and output folder, if needed.
    if ~exist ( config.path.fooof, 'dir' ), mkdir ( config.path.fooof ); end
    if ~exist ( config.path.apexp, 'dir' ), mkdir ( config.path.fooof ); end


    % Gets the files list.
    files = dir ( fullfile ( config.path.pow, config.path.patt ) );
    start = 1;

    % Goes through all the files.
    for findex = start: numel ( files )


        % Preload the data
        powdata         = load ( fullfile ( config.path.pow, files ( findex ).name ),'subject', 'task', 'channel', 'whitener', 'lambda', 'taper');

        % Gets the text of the message.
        msgtext          = sprintf ( 'subject ''%s'', task ''%s''', powdata.subject, powdata.task );
        msgtext          = sprintf ( '%s, channel group ''%s''', msgtext, powdata.channel );

        if exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_fooof_rois.mat', powdata.subject, powdata.task, powdata.channel) ), 'file' ) && ~config.overwrite
            fprintf ( 1, 'Ignoring %s (Already calculated).\n', msgtext );
            continue

        elseif exist ( fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_fooof_rois.mat', powdata.subject, powdata.task, powdata.channel) ), 'file' ) && config.overwrite
            
            fooofdata = load(fullfile ( config.path.fooof, sprintf ( '%s_%s_%s_fooof_rois.mat', powdata.subject, powdata.task, powdata.channel) ));
        
        else
            % Prepares the output.
            fooofdata          = [];
            fooofdata.subject  = powdata.subject;
            fooofdata.task     = powdata.task;
            fooofdata.channel  = powdata.channel;
            fooofdata.whitener = powdata.whitener;
            fooofdata.lambda   = powdata.lambda;
            fooofdata.taper    = powdata.taper;
        end

        fprintf ( 1, 'Working with %s.\n', msgtext );

        fprintf ( 1, '  Loading the data.\n' );

        % Loads the power data.
        powdata       = load ( fullfile ( config.path.pow, files ( findex ).name ) );
        nfreq = numel ( powdata.band.sources.freq );

        % Initialize power structure
        avgpow =  zeros ( nrois , nfreq );
        svdpow = zeros (nrois,nfreq);

        % Average power for each roi
        for iRoi = 1:nrois

            roi_mask = ismember ( template.grid.area, iRoi );

            % Use normalized power spectrum to account higher amplitudes
            % in internal sources due to the beamformer
            pow_roi = powdata.band.sources.normpow ( roi_mask, : );

            avgpow (iRoi, : ) = mean ( pow_roi );

            [u,s,v] = svd(pow_roi,'econ');
            rep_pow = v(:,1);
            roi_weights = u(:,1) * s(1,1);

            if corr(rep_pow, avgpow(iRoi,:)') < 0
                rep_pow = -rep_pow;
                roi_weights = -roi_weights;
            end

            svdpow(iRoi,:) = rep_pow;

            % rep_norm = rep_pow / max(rep_pow);
            % avg_norm = avgpow(iRoi,:) / max(avgpow(iRoi,:));
            % 
            % figure
            % plot(powdata.band.sources.freq,rep_norm, 'LineWidth', 2)
            % hold on
            % plot(powdata.band.sources.freq,avg_norm,'LineWidth', 2)
            % hold on
            % plot(powdata.band.sources.freq,pow_roi)

        end


        if config.avg
            % Create fooofgroup object and fit the average power spectrum for each roi
            tic
            fg_avg = fooofGroup('freq_range', config.fooofband ,'peak_width_limits', config.peak_width_limits ,'aperiodic_mode', config.aperiodic_mode);
            fg_avg = add_data(fg_avg, powdata.band.sources.freq, double(avgpow));
            fg_avg = fit(fg_avg);
            fprintf (1, '  Fooof fit AVERAGE took %.2f s.\n', toc);

            % Extract aperiodic exponent from fooofgroup object
            apexp_avg = cellfun(@(x) x.aperiodic_params(end), fg_avg.group_results);

            % Get R squared from the modelled PSDs
            r2 = cellfun(@(x) x.r_squared, fg_avg.group_results);

            % Discard apex from PSDs with poor fitting
            apexp_avg(r2 < config.r2_thres) = nan;

            fooofdata.fm_avg   = fg_avg;
            fooofdata.apexp_avg = apexp_avg;

        end


        if config.svd
            % Create fooofgroup object and fit the svd representative power spectrum for each roi
            tic
            fg_svd = fooofGroup('freq_range', config.fooofband ,'peak_width_limits', config.peak_width_limits ,'aperiodic_mode', config.aperiodic_mode);
            fg_svd = add_data(fg_svd, powdata.band.sources.freq, double(svdpow));
            fg_svd = fit(fg_svd);
            fprintf (1, '  Fooof fit SVD took %.2f s.\n', toc);

            % Extract aperiodic exponent from fooofgroup object
            apexp_svd = cellfun(@(x) x.aperiodic_params(end), fg_svd.group_results);

            % Get R squared from the modelled PSDs
            r2 = cellfun(@(x) x.r_squared, fg_svd.group_results);

            % Discard apex from PSDs with poor fitting
            apexp_svd(r2 < config.r2_thres) = nan;

            fooofdata.fm_svd = fg_svd;
            fooofdata.apexp_svd = apexp_svd;

        end


        % Save or update the data
        save ( '-v6', fullfile ( config.path.fooof,  sprintf ( '%s_%s_%s_fooof_rois.mat', fooofdata.subject, fooofdata.task, fooofdata.channel) ) , '-struct', 'fooofdata' );

    end
end


