function freqdata = myft_freqanalysis ( config, trialdata )

% Sets the default options.
if ~isfield ( config, 'method' ),     config.method     = 'mtmfft'; end
if ~isfield ( config, 'keeptrials' ), config.keeptrials = false;    end
if ~isfield ( config, 'output' ),     config.output     = 'power';  end

if ~strcmp ( config.method, 'mtmfft' ), error ( 'Invalid method.' ), end

if ischar ( config.keeptrials ), config.keeptrials = strcmp ( config.keeptrials, 'yes' ); end

% Defines the output.
switch config.output
    case 'power'
        getpow = true;
        getcsd = false;
        getfft = false;
    case 'powandcsd'
        getpow = true;
        getcsd = true;
        getfft = false;
    case 'fourier'
        getpow = false;
        getcsd = false;
        getfft = true;
        config.keeptrials = true;
    otherwise
        error ( 'Unknown output.' )
end


% Extracts and demeans the data.
rawtime      = cat ( 3, trialdata.trial {:} );
rawtime      = rawtime - mean ( rawtime, 2 );

% Gets the data dimensions.
nsample      = size ( rawtime, 2 );


% Generates the Slepian tapers, if requested.
if strcmp ( config.taper, 'dpss' )
    taper        = dpss ( nsample, nsample * ( config.tapsmofrq / trialdata.fsample ) )';
    taper        = taper ( 1: end - 1, : );
    
% Otherwise generates a normalized taper.
else
    taper        = window ( config.taper, nsample )';
    taper        = taper / norm ( taper );
end


% Generates the frequencies vector.
freqs        = ( 0: nsample - 1 ) / ( nsample / trialdata.fsample );

% Selects the band of frequencies, if provided.
if isfield ( config, 'foilim' ) && ~isempty ( config.foilim )
    freqindex    = freqs >= config.foilim (1) & freqs <= config.foilim (2);
else
    freqindex    = freqs <= trialdata.fsample / 2;
end
freqs        = freqs ( freqindex );


% Gets the data dimensions.
nchan        = size ( rawtime, 1 );
nsample      = size ( rawtime, 2 );
ntrial       = size ( rawtime, 3 );
ntaper       = size ( taper, 1 );
nfreq        = numel ( freqs );

% Initializes the frequency matrices.
rawft        = zeros ( nchan, nfreq, ntrial, ntaper, getfft, 'like', single ( 1i ) );
rawpow       = zeros ( nchan, nfreq, ntrial, getpow, 'like', single ( 1 ) );

% Goes through each taper.
for tindex = 1: ntaper
    
    % Applies the taper.
    tapdata      = rawtime .* taper ( tindex, : );
    
    % Calculates the (corrected) Fourier transform of the data.
    tapfft       = fft ( tapdata, [], 2 ) ./ sqrt ( nsample );
    
    % Keeps only the selected frequencies.
    tapfft       = tapfft ( :, freqindex, : );
    
    % Corrects the amplitude with the imaginary part.
    fixfreq      = freqs > 0 & freqs < trialdata.fsample / 2;
    tapfft ( :, fixfreq, : ) = sqrt (2) * tapfft ( :, fixfreq, : );
    
    
    % Stores the Fourier transform, if requested.
    if getfft
        rawft ( :, :, :, tindex ) = tapfft;
    end
    
    
    % Gets the power spectra for this taper, if requested.
    if getpow
        tappow       = abs ( tapfft ) .^ 2;
        
        % Stores the power spectra.
        rawpow       = rawpow + tappow;
    end
    
    
    % Gets the CSD matrix for this taper, if requested.
    if getcsd
        % Defines all the possible combinations of channels.
        chanpairs    = combnk ( 1: nchan, 2 );
        npairs       = size ( chanpairs, 1 );
        rawcsd       = zeros ( npairs, nfreq, ntrial, getcsd, 'like', single ( 1i ) );

        fourier1     = tapfft ( chanpairs ( :, 1 ), :, : );
        fourier2     = tapfft ( chanpairs ( :, 2 ), :, : );
        tapcsd       = conj ( fourier1 ) .* fourier2;
        
        % Stores the CSD matrix.
        rawcsd       = rawcsd + tapcsd;
    end
end

% Divides the taper-averages by the number of tapers.
rawpow       = rawpow / ntaper;

if getcsd
    rawcsd       = rawcsd / ntaper;
end


% Averages by trial, if requested.
if ~config.keeptrials
    rawpow       = mean ( rawpow, 3 );
    if getcsd 
        rawcsd       = mean ( rawcsd, 3 );
    end
    
% Otherwise re-writes the matrices in FieldTrip format.
else
    
    rawpow       = permute ( rawpow, [ 3 1 2 4 ] );
    if getcsd
        rawcsd       = permute ( rawcsd, [ 3 1 2 4 ] );
    end
    rawft        = permute ( rawft, [ 1 2 4 3 5 ] );
    rawft        = rawft ( :, :, : );
    rawft        = permute ( rawft, [ 3 1 2 ] );
end


% Prepares the output in FieldTrip format.
freqdata           = [];
freqdata.label     = trialdata.label;
freqdata.freq      = freqs;

% Stores the Fourier spectra, if requested.
if getfft
    freqdata.fourierspctrm = rawft;
end
% Stores the power spectra, if requested.
if getpow
    freqdata.powspctrm = rawpow;
end
% Stores the CSD matrix, if requested.
if getcsd
    freqdata.labelcmb  = freqdata.label ( chanpairs );
    freqdata.crsspctrm = rawcsd;
end

if getfft
    freqdata.dimord    = 'rpttap_chan_freq';
    freqdata.cumsumcnt = repmat ( nsample, ntrial, 1 );
    freqdata.cumtapcnt = repmat ( ntaper, ntrial, 1 );
elseif config.keeptrials
    freqdata.dimord    = 'rpt_chan_freq';
else
    freqdata.dimord    = 'chan_freq';
end

if config.keeptrials && isfield ( trialdata, 'trialinfo' )
    freqdata.trialinfo = trialdata.trialinfo;
end
