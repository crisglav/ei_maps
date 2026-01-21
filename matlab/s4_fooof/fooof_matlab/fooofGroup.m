classdef fooofGroup < fooof
    properties
        power_spectra
        ap_fit_group
        fooofed_spectrum_group
        group_results

    end
    
    methods
        function obj = fooofGroup(varargin)
            % constructor of fooofGroup object. It is derived from class fooof
            obj@fooof(varargin{:});
        end     
        
        function obj = add_data(obj,freq,pow)
            % Add data to fooof model. Powspectrum must be in linear scale.                      
            % Trim power spectra if freq range is specified. Otherwise keep all the data
            if size(pow,1) == 1
                warning('Only one power spectrum given. Use a fooof object.')
            end
            obj.freq_orig = freq;
            obj.pow_orig = pow;
            if ~isempty(obj.freq_range)
                mask = and(freq >= obj.freq_range(1),freq<=obj.freq_range(2));
                obj.freqs = freq(mask);
                obj.power_spectra = log10(pow(:,mask));
            else
                obj.freqs = freq;
                obj.power_spectra = log10(pow);
            end
            obj.freq_res = freq(2) - freq(1);            
            if obj.peak_width_limits(1) <= obj.freq_res 
                str = sprintf('Lower bound peak width limit is < or = the frequency resolution: %.2f <= %.2f. Too low a limit may lead to overfitting noise. We recommend a lower bound of approximately twice the frequency resolution.', obj.peak_width_limits(1),obj.freq_res);
                warning(str);
            end
            obj.group_results = cell(1,size(obj.power_spectra,1));


        end
        
        function obj = fit(obj)
            for i=1:size(obj.power_spectra,1)
                obj.power_spectrum = obj.power_spectra(i,:);
                obj = fit@fooof(obj);
                obj.group_results{i} = get_results(obj);
                obj.ap_fit_group(i,:) = obj.ap_fit;
                obj.fooofed_spectrum_group(i,:) = obj.fooofed_spectrum;
            end
        end
     
        
    end
end

