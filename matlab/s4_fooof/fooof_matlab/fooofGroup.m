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

        function fig = plot(obj,varargin)
        if nargin > 0
                p = inputParser;
                % TO DO: Do extra checks to the freq range (freq2 > freq1)
                addParameter(p,'fig_save',false,@islogical);
                addParameter(p,'file_name','');
                addParameter(p,'file_path','');
                addParameter(p,'rois','all');
                parse(p,varargin{:})
                
                fig_save = p.Results.fig_save;
                file_name = p.Results.file_name;
                file_path = p.Results.file_path;
                rois = p.Results.rois;
         end    
            
         if strcmp(rois,'all')
             rois = ones(size(obj.ap_fit_group,1),1);
         end
            % Overlap the fooofed spectrum to the original spectrum in full frequency range
            
            padded_ap_fit = nan(sum(rois), size(obj.freq_orig,2));
            fmask = and(obj.freq_orig >= obj.freq_range(1),obj.freq_orig<=obj.freq_range(2));
            padded_ap_fit(:,fmask) = obj.ap_fit_group(rois,:);
            padded_fooofed_spectrum = nan(sum(rois), size(obj.freq_orig,2));
            padded_fooofed_spectrum(:,fmask) = obj.fooofed_spectrum_group(rois,:);

            nLines = sum(rois);
            idx = find(rois);
            color = turbo(nLines);
            alpha = 0.5;

            fig = figure('Units','centimeters','Position',[15 10 20 15]);
            ax = gca;
            hold on
            for k = 1:nLines
                
                % Plot solid
                plot(obj.freq_orig, log10(obj.pow_orig(idx(k),:)), 'Color', [color(k,:) alpha], 'LineWidth', 1.5);
                
                % Plot dashed (same color)
                plot(obj.freq_orig, padded_ap_fit(k,:), '--', 'Color', [color(k,:) alpha], 'LineWidth', 0.5);
                
                % Plot fooofed power spectrum
                plot(obj.freq_orig,padded_fooofed_spectrum(k,:), 'Color', [color(k,:) alpha], 'LineWidth', 0.5);

            end

            % legend ({'Original spectrum','Aperiodic fit','Full model fit'});
            xlabel('Frequency');
            ylabel('logPower');
            title(sprintf('Model fit %d - %d Hz',obj.freq_range));
            % str1 = sprintf('r2 = %0.3f ',obj.r_squared);
            % str2 = sprintf('mae = %0.3f',obj.model_error(1));
            % text('Units', 'Normalized', 'Position', [0.05, 0.1],'String',{str1,str2});
            
            if(fig_save)
                if(isempty(file_name))
                    error('Specify a valid file_name');
                end
                exportgraphics(ax,fullfile(file_path,[file_name '.pdf']));
            end

        end
     
        
    end
end

