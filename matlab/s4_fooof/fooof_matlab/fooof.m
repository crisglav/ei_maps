classdef fooof
    
    properties(Access = public)
        % Parameters (with default settings)
        freq_range        = [2 40];
        peak_width_limits = [0.5 12];
        max_n_peaks       = inf;
        min_peak_height   = 0;
        peak_threshold    = 2;
        aperiodic_mode    = 'fixed';
        
        % Data attributes
        pow_orig
        freq_orig
        power_spectrum
        freqs
        freq_res
        inital_spectrum_flat
        spectrum_flat
        spectrum_peak_rm
        
        % Model component attributes
        initial_ap_fit
        ap_fit
        peak_fit        
        fooofed_spectrum
        
        % Model parameters
        aperiodic_params    % [Offset, (Knee), Exponent]
        gaussian_params     % [mean, height, standard deviation]
        peak_params         % [CF, PW, BW]
        error               % [mae, mse, rmse]
        r_squared
        
    end
    
    properties(Access = private)
        % Aperiodic computation parameters
        ap_percentile_thresh = 0.025;
        
        % Fitting peak parameters
        bw_std_edge = 1;
        gauss_overlap_thresh = 0.75;
        cf_bound = 1.5;
        gauss_std_limits;       
    end
        
    methods
        function obj = fooof(varargin)
            % constructor of fooof object            
            if nargin > 0
                p = inputParser;
                % TO DO: Do extra checks to the freq range (freq2 > freq1)
                addParameter(p,'freq_range',[2, 40],@(x)validateattributes(x,{'numeric'},{'numel',2}));
                addParameter(p,'peak_width_limits',[0.5, 12],@(x)validateattributes(x,{'numeric'},{'numel',2}));
                addParameter(p,'max_n_peaks',inf,@(x)validateattributes(x,{'numeric'},{'scalar'}));
                addParameter(p,'min_peak_height',0,@(x)validateattributes(x,{'numeric'},{'scalar'}));
                addParameter(p,'peak_threshold',2,@(x)validateattributes(x,{'numeric'},{'scalar'}));
                addParameter(p,'aperiodic_mode','fixed', @(x) any(validatestring(x,{'fixed','knee'})));

                parse(p,varargin{:})
                
                obj.freq_range = p.Results.freq_range;
                obj.peak_width_limits = p.Results.peak_width_limits;
                obj.max_n_peaks = p.Results.max_n_peaks;
                obj.min_peak_height = p.Results.min_peak_height;
                obj.peak_threshold = p.Results.peak_threshold;
                obj.aperiodic_mode = p.Results.aperiodic_mode;
            end
        end
        
        function obj = add_data(obj,freq,pow)
            % Add data to fooof model. Powspectrum must be in linear scale.                      
            % Trim power spectra if the predefined freq range is not empty. If freq_range is empty keep all the data.
            
            % Check data format
            if size(pow,1) > 1
                error('fooof class does not support multiple power spectra. Use class fooofGroup');
            end
            
            % TO DO: more checks here
            % - same length freq and pow
            % - no inf or nan values
            % - check if values are complex
            % - check that freqs has a wider range than obj.freq_range
            
            obj.freq_orig = freq;
            obj.pow_orig = pow;
            
            if ~isempty(obj.freq_range)
                mask = and(freq >= obj.freq_range(1),freq<=obj.freq_range(2));
                obj.freqs = freq(mask);
                obj.power_spectrum = log10(pow(mask));
                fprintf('Data trimmed in the range %d - %d Hz \n',obj.freq_range)
            else
                obj.freqs = freq;
                obj.power_spectrum = log10(pow);
            end
            obj.freq_res = freq(2) - freq(1);
            if obj.peak_width_limits(1) <= obj.freq_res
                str = sprintf('Lower bound peak width limit is < or = the frequency resolution: %.2f <= %.2f. Too low a limit may lead to overfitting noise. We recommend a lower bound of approximately twice the frequency resolution.', obj.peak_width_limits(1),obj.freq_res);
                warning(str);
            end

        end
        
        function obj = fit(obj)
            % Fit FOOOF model to power spectrum
            
            % ===== Robust aperiodic fit =====
            obj.aperiodic_params = robust_ap_fit(obj,obj.freqs,obj.power_spectrum);
            obj.ap_fit = exp_function(obj.aperiodic_params, obj.freqs);
            obj.initial_ap_fit = obj.ap_fit; % For visualization later on because it is overwritten
            
            % ===== Flatten the power spectrum using fit aperiodic fit =====
            obj.spectrum_flat = obj.power_spectrum - obj.ap_fit;
            obj.inital_spectrum_flat = obj.spectrum_flat; % For visualization
            
            % ===== Find peaks and fit them with gaussians ======
            obj.gaussian_params = fit_peaks(obj,obj.spectrum_flat);
            
            % Calculatte the peak fit
            gaussian_params = reshape(obj.gaussian_params',1,[]);
            obj.peak_fit = gaussian_function(gaussian_params,obj.freqs);
            
            % ===== Create peak-removed (but not flattened) power spectrum =====
            obj.spectrum_peak_rm = obj.power_spectrum - obj.peak_fit;
            
            % ===== Run the final aperiodic fit on peak-removed power spectrum ======
            % This overwrites the previous aperiodic fit, and recomputes flattened spectrum
            obj.aperiodic_params = simple_ap_fit(obj,obj.freqs,obj.spectrum_peak_rm);
            obj.ap_fit = exp_function(obj.aperiodic_params, obj.freqs);
            obj.spectrum_flat = obj.power_spectrum - obj.ap_fit;
            
            % ===== Create full power spectrum model ====
            obj.fooofed_spectrum = obj.peak_fit + obj.ap_fit;
            
            % ===== Convert gaussian definitions to peak parameters =====
            obj.peak_params = create_peak_params(obj,obj.gaussian_params);
            
            % ===== Calculate R^2 and error of the model fit ======
            obj.r_squared = calc_r_squared(obj);
            obj.error = calc_error(obj);
        end
        
        
        function aperiodic_params = simple_ap_fit(obj,freq,pow)
            % Fit the aperiodic component of the power spectra
        
            % Guess initial values
            off_guess = pow(1);
            knee_guess = 0;
            exp_guess = abs((pow(end)-pow(1))/(log10(freq(end))-log10(freq(1))));
            
            % Fitting options
            options = optimoptions('lsqcurvefit');
            options.MaxFunctionEvaluations = 5000;
            options.FunctionTolerance = 1e-8;
            switch obj.aperiodic_mode
                case 'knee'
                    lo_bound = [-inf, -inf -inf];
                    hi_bound = [inf, inf, inf];
                    guess = [off_guess, knee_guess, exp_guess];
                otherwise
                    lo_bound = [-inf, -inf];
                    hi_bound = [inf, inf];
                    guess = [off_guess exp_guess];
            end
            % Fitting
            aperiodic_params = lsqcurvefit(@exp_function,guess,freq',pow',lo_bound,hi_bound,options);
            % The fitting can sometimes return aperiodic params in form of a complex number with imaginary part equal to zero
            if ~isreal(aperiodic_params)
                % Check whether the imaginary part is zero with certain tolerance
                tol = 0.0001;
                if(all(imag(aperiodic_params)<tol)) % Assume that the imaginary parts are zero and cast to real
                    aperiodic_params = real(aperiodic_params);
                else
                    warning('The simple aperiodic fitting returned imaginary numbers. Using only the real part.')
                    aperiodic_params = real(aperiodic_params);
                end
            end
        end

        function aperiodic_params = robust_ap_fit(obj,freq,pow)
            % Do initial robust aperidoic fit
            guess = simple_ap_fit(obj,freq,pow);
            initial_fit = exp_function(guess, freq);
            
            % Flatten powe spectrum based on initial aperiodic fit
            flatspec = pow - initial_fit;
            
            % Flatten outliers, defined as any points that drop below 0
            flatspec(flatspec < 0) = 0;
            
            % Use percentile threshold, intermos of points to extract and re-fit
            perc_thresh = prctile(flatspec, obj.ap_percentile_thresh);
            perc_mask = flatspec <= perc_thresh;
            freqs_ignore = freq(perc_mask);
            spectrum_ignore = pow(perc_mask);
            
            % Second aperiodic fit, using results of first fit as guess parameters
            options = optimoptions('lsqcurvefit');
            options.MaxFunctionEvaluations = 5000;
            options.FunctionTolerance = 1e-8;
            switch obj.aperiodic_mode
                case 'knee'
                    lo_bound = [-inf, -inf -inf];
                    hi_bound = [inf, inf, inf];
                otherwise % 'fixed'
                    % Aperiodic bounds (hard coded)
                    lo_bound = [-inf, -inf];
                    hi_bound = [inf, inf];
            end
            aperiodic_params = lsqcurvefit(@exp_function,guess,freqs_ignore',spectrum_ignore',lo_bound,hi_bound,options);
            % The fitting can sometimes return aperiodic params in form of a complex number with imaginary part equal to zero
            if ~isreal(aperiodic_params)
                % Check whether the imaginary part is zero with certain tolerance
                tol = 0.0001;
                if(all(imag(aperiodic_params)<tol)) % Assume that the imaginary parts are zero and cast to real
                    aperiodic_params = real(aperiodic_params);
                else
                    error('The simple aperiodic fitting returned imaginary numbers.')
                end
            end
        end
        
        function gaussian_params = fit_peaks(obj,flat_iter)
            obj.gauss_std_limits = obj.peak_width_limits/2;
            if(isinf(obj.max_n_peaks))
                guess = zeros(100,3);
            else
                guess = zeros(obj.max_n_peaks,3);
            end
            
            lguess = 1;
            while lguess <= obj.max_n_peaks
                
                % Find candidate peak - the maximum point of the flattened spectrum
                [max_height, max_ind] = max(flat_iter);
                
                % Stop searching for peaks once height drops below height threshold
                if max_height <= obj.peak_threshold * std(flat_iter,1)
                    lguess = lguess -1;
                    break
                end
                
                % set the guess parameters for gaussian fitting, specifying the mean and
                % height
                guess_freq = obj.freqs(max_ind);
                guess_height = max_height;
                
                % Stop fitting process if candidate peak drops below minimum height
                if not(guess_height > obj.min_peak_height)
                    lguess = lguess -1;
                    break
                end
                
                % Data driven first guess at standard deviation
                % Find half heiht index on each side of the center frequency
                half_height = 0.5 * max_height;
                
                le_ind = find(flat_iter(2:max_ind) <= half_height,1,'last'); % in the python implementation it goes up to the second position of flat_iter
                ri_ind = max_ind + find(flat_iter(max_ind:end) <= half_height,1) -1;
                if isempty(le_ind), le_ind = nan; end
                if isempty(ri_ind), ri_ind = nan; end
                
                try
                    % Guess the bandwidth of the peak based on the short side
                    short_side = min(max_ind - le_ind, ri_ind - max_ind);
                    
                    % Full width half max
                    fwhm = short_side * 2 * obj.freq_res;
                    guess_std = fwhm/(2*sqrt(2*log(2)));
                catch
                    guess_std = mean(obj.peak_width_limits);
                end
                
                % Check that the guess value isn't outside preset limits - restrict if
                % so
                if guess_std < obj.gauss_std_limits(1)
                    guess_std = obj.gauss_std_limits(1);
                end
                if guess_std > obj.gauss_std_limits(2)
                    guess_std = obj.gauss_std_limits(2);
                end
                
                % Collect guess parameters and substract this guess gaussian from thee
                % data
                guess(lguess,:) = [guess_freq, guess_height, guess_std];
                
                % Fit the gaussian function
                g = guess_height * exp(-(obj.freqs - guess_freq).^2 / (2*guess_std^2));
                
                % Substract the modelled gaussian from the power spectrum
                flat_iter = flat_iter - g;
                lguess = lguess+1;
            end
            if(lguess > obj.max_n_peaks)
                lguess = obj.max_n_peaks;
            end
            % Remove rows without peaks
            guess = guess(1:lguess,:);
            % Check the peaks based on edges, and on overlap, dropping any that violate
            % requirements
            guess = drop_peak(obj,guess);
            guess = drop_peak_overlap(obj,guess);
            
            if ~isempty(guess)
                gaussian_params = fit_peak_gauss(obj,guess);
                [~, ix] = sort(gaussian_params(:,1));
                gaussian_params = gaussian_params(ix,:);
            else
                gaussian_params = [];
            end
            
        end
        
        function guess = drop_peak(self,guess)
            % Center frequency, Bandwidth
            cf = guess(:,1);
            bw = guess(:,3) * self.bw_std_edge;
            
            % Check if peaks within drop threshold from the edge of the freq range
            keep_peaks = and(abs(cf - self.freq_range(1)) > bw, abs(cf - self.freq_range(2)) > bw);
            
            % Remove peaks that do not fullfil the frequency edge criterion
            guess = guess(keep_peaks,:);
        end
        
        function guess = drop_peak_overlap(self,guess)
            % Sort the peak guesses by increasing frequency
            [~, ix] = sort(guess(:,1));
            guess = guess(ix,:);
            
            % Calculate the std bounds for checking the amount of overlap
            % The bounds are the gaussian frequency +/- gaussian standard deviation
            bounds = [guess(:,1) - guess(:,3)*self.gauss_overlap_thresh, guess(:,1) + guess(:,3)*self.gauss_overlap_thresh] ;
            
            % Loop through peak bounds, comparing current bound to that of the next
            % peak. If the left peak's upper bound extends pass the reight peaks
            % lower bound, then drop the gaussian with the lower height.
            drop_ind = zeros(1,size(bounds,1));
            for i = 1:size(bounds,1)-1
                if bounds(i,2) > bounds(i+1,1)
                    
                    [~,ix] = min([guess(i,2),guess(i+1,2)]);
                    drop_ind(i+ix-1) = 1;
                end
            end
            guess = guess(~drop_ind,:);
            
        end
        
        function gauss_params = fit_peak_gauss(self,guess)
            n_peaks = size(guess,1);
            % Set the bounds for CF
            lo_bound = [guess(:,1) - 2*self.cf_bound *guess(:,3), zeros(n_peaks,1), repmat(self.gauss_std_limits(1),n_peaks,1)];
            hi_bound = [guess(:,1) + 2*self.cf_bound*guess(:,3),inf(n_peaks,1),repmat(self.gauss_std_limits(2),n_peaks,1)];
            
            % Check that CF bounds are within frequency range
            ix = lo_bound(:,1) < self.freq_range(1);
            lo_bound(ix,1) = self.freq_range(1);
            ix = hi_bound(:,1) > self.freq_range(2);
            hi_bound(ix,1) = self.freq_range(2);
            
            % Fit the multiple gaussians
            beta0 = reshape(guess',1,[]); % Starting point
            lb = reshape(lo_bound',1,[]); % Lower bound
            up = reshape(hi_bound',1,[]); % Upper bound
            options = optimoptions('lsqcurvefit');
            options.MaxFunctionEvaluations = 5000;
            options.FunctionTolerance = 1e-8;
            beta = lsqcurvefit(@gaussian_function,beta0,self.freqs',self.spectrum_flat',lb,up,options);
            gauss_params = reshape(beta,3,[])';
        end
        
        function peak_params = create_peak_params(obj,gaussian_params)
            peak_params = zeros(size(gaussian_params));
            n_peaks = size(gaussian_params,1);
            for i=1:n_peaks
                % Get the index of the power spectrum at the frequency closest to the cf of the peak
                [~,ix]= min(abs(obj.freqs - gaussian_params(i,1)));
                peak_params(i,1) = gaussian_params(i,1);
                peak_params(i,2) = obj.fooofed_spectrum(ix) - obj.ap_fit(ix);
                peak_params(i,3) = gaussian_params(i,3)*2;
            end
        end
        
        function error = calc_error(obj)
            % Mean absolute error
            mae = mean(abs(obj.power_spectrum - obj.fooofed_spectrum));
            % Mean squared error
            mse = mean((obj.power_spectrum - obj.fooofed_spectrum).^2);
            % Root mean squared error
            rmse = sqrt(mean((obj.power_spectrum - obj.fooofed_spectrum).^2));
            error = [mae, mse, rmse];
        end
        
        function r2 = calc_r_squared(obj)
            r2 = corr(obj.power_spectrum', obj.fooofed_spectrum')^2;
        end
        
        function results = get_results(obj)
            % Parameters
            % ----------
            % aperiodic_params : 1d array
            %     Parameters that define the aperiodic fit. As [Offset, (Knee), Exponent].
            %     The knee parameter is only included if aperiodic is fit with knee.
            % peak_params : 2d array
            %     Fitted parameter values for the peaks. Each row is a peak, as [CF, PW, BW].
            % r_squared : float
            %     R-squared of the fit between the full model fit and the input data.
            % error : float
            %     Error of the full model fit as [MAE MSE RMSE]
            % gaussian_params : 2d array
            %     Parameters that define the gaussian fit(s).
            %     Each row is a gaussian, as [mean, height, standard deviation].
            results.aperiodic_params = obj.aperiodic_params;
            results.peak_params = obj.peak_params;
            results.r_squared = obj.r_squared;
            results.error = obj.error;
            results.gaussian_params = obj.gaussian_params;       
        end
        
        function fig = plot(obj,varargin)
        if nargin > 0
                p = inputParser;
                % TO DO: Do extra checks to the freq range (freq2 > freq1)
                addParameter(p,'fig_save',false,@islogical);
                addParameter(p,'file_name','');
                addParameter(p,'file_path','');
                parse(p,varargin{:})
                
                fig_save = p.Results.fig_save;
                file_name = p.Results.file_name;
                file_path = p.Results.file_path;
         end    
            
            % Overlap the fooofed spectrum to the original spectrum in full frequency range
            padded_ap_fit = nan(size(obj.freq_orig));
            fmask = and(obj.freq_orig >= obj.freq_range(1),obj.freq_orig<=obj.freq_range(2));
            padded_ap_fit(fmask) = obj.ap_fit;
            padded_fooofed_spectrum = nan(size(obj.freq_orig));
            padded_fooofed_spectrum(fmask) = obj.fooofed_spectrum;
            
            fig = figure('Units','centimeters','Position',[15 10 20 15]);
            ax = gca;
            plot(obj.freq_orig,log10(obj.pow_orig),'k');
            hold on
            plot(obj.freq_orig,padded_ap_fit,'--b')
            hold on
            plot(obj.freq_orig,padded_fooofed_spectrum,'r');
            legend ({'Original spectrum','Aperiodic fit','Full model fit'});
            xlabel('Frequency');
            ylabel('logPower');
            title(sprintf('Model fit %d - %d Hz',obj.freq_range));
            str1 = sprintf('r2 = %0.3f ',obj.r_squared);
            str2 = sprintf('mae = %0.3f',obj.error(1));
            text('Units', 'Normalized', 'Position', [0.05, 0.1],'String',{str1,str2});
            
            if(fig_save)
                if(isempty(file_name))
                    error('Specify a valid file_name');
                end
                exportgraphics(ax,fullfile(file_path,[file_name '.pdf']));
            end
                
        end
        
        

    end

end