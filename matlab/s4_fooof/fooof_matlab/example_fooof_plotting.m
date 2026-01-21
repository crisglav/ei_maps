% Script testing the reimplementation of fooof in Matlab
%
% Original python code by Tom Donoghue et. al in https://github.com/fooof-tools/fooof
%
% Cristina Gil Avila, TUM, 01.09.2023
close all
clear all
%% Loading demo data
power_path = '../../results/features/power/PFC/';
power_files = dir(fullfile(power_path,'*.mat'));
file = power_files(1);
load(fullfile(file.folder,file.name));

% Average across virtual channels
avgpow = mean(pow,1);

%% Fit fooof model
% Initialize fooof object with some default settings
fm = fooof('freq_range',[2 40],'aperiodic_mode','knee');
% Add data to the model in the freq range 2 - 40 Hz (pre-specified)
fm = add_data(fm,freq,avgpow);
fm = fit(fm);
fm.get_results()
fm.plot('fig_save',true,'file_name',file.name(1:7));
%% Some plotting
% Reproducing figures of tutorial 3 of fooof (jupyter notebook)
fig2 = figure('Units','centimeters','Position',[15 15 35 35]);
tiledlayout(3,3);

% Figure1, non-log scale, full frequency range
nexttile;
plot(fm.freq_orig,log10(fm.pow_orig),'k');
xlabel('Frequency');
ylabel('Power');
title('Original PSD');

% Figure 2: Initial robust aperiodic fit
nexttile;
plot(fm.freqs,fm.power_spectrum,'k');
hold on
plot(fm.freqs,fm.initial_ap_fit,'--b');
legend({'Original power spectrum','Initial robust aperiodic fit'});
xlabel('Freqency');
ylabel('logPower');
title('Step 1: Initial robust aperiodic fit');

% Figure 3: Flat spectrum
nexttile;
plot(fm.freqs,fm.inital_spectrum_flat,'k');
legend ('Flattened Spectrum');
xlabel('Frequency');
ylabel('logPower');
title('Step 2: Removed aperiodic component from original PSD');

% Figure 5: Gaussian periodic fit
nexttile;
plot(fm.freqs,fm.peak_fit,'g');
legend ('Final periodic fit');
xlabel('Frequency');
ylabel('logPower');
title('Step 3: Result of multi gaussian fit');

% Figure 6: Peak removed spectrum
nexttile;
plot(fm.freqs,fm.spectrum_peak_rm,'k');
legend ('Peak removed spectrum');
xlabel('Frequency');
ylabel('logPower');
title('Step 4: Remove gaussians from original PSD');

% Figure 7: Final aperiodic fit
nexttile;
plot(fm.freqs,fm.spectrum_peak_rm,'k');
hold on
plot(fm.freqs,fm.ap_fit,'--b')
legend ({'Peak removed spectrum','Final Aperiodic Fit'});
xlabel('Frequency');
ylabel('logPower');
title('Step 5: Re-fit aperiodic component');

% Figure 8: Full model fit
nexttile;
plot(fm.freqs,fm.fooofed_spectrum,'r');
legend ('Full model');
xlabel('Frequency');
ylabel('logPower');
title('Combined model: Gaussian + aperiodic fit');

% Figure 9
nexttile;
plot(fm.freqs,fm.power_spectrum,'k');
hold on
plot(fm.freqs,fm.ap_fit,'--b')
hold on
plot(fm.freqs,fm.fooofed_spectrum,'r');
legend ({'Original spectrum','Aperiodic fit','Full model fit'});
xlabel('Frequency');
ylabel('logPower');
title('Assess goodness of fit');

%% Playzone
% I think it would be interesting to know how well the model fitted in the freq_range extrapolates to the full spectrum

% Calculate peak fit on the full frequency range
gaussian_params = reshape(fm.gaussian_params',1,[]);
peak_fit_full = gaussian_function(gaussian_params,fm.freq_orig);

% Run the aperiodic fit on the whole power spectrum
ap_fit_full = exp_function(fm.aperiodic_params, fm.freq_orig);
spectrum_flat_full = fm.pow_orig - ap_fit_full;

% Create full power spectrum model
fooofed_spectrum_full = peak_fit_full + ap_fit_full;

% Calculate R^2 and error of the model fit
r2 = corr(log10(fm.pow_orig)', fooofed_spectrum_full')^2;
mae = mean(abs(log10(fm.pow_orig) - fooofed_spectrum_full));
mse = mean((log10(fm.pow_orig) - fooofed_spectrum_full).^2);
rmse = sqrt(mean((log10(fm.pow_orig) - fooofed_spectrum_full).^2));

% Plotting
% Overlap the fooofed spectrum to the original spectrum in full frequency range
padded_ap_fit = nan(size(fm.freq_orig));
fmask = and(fm.freq_orig >= fm.freq_range(1),fm.freq_orig<=fm.freq_range(2));
padded_ap_fit(fmask) = fm.ap_fit;
padded_fooofed_spectrum = nan(size(fm.freq_orig));
padded_fooofed_spectrum(fmask) = fm.fooofed_spectrum;

fig = figure('Units','centimeters','Position',[15 15 35 14]);
tlc = tiledlayout(1,2);
ax = nexttile;
plot(fm.freq_orig,log10(fm.pow_orig),'k');
hold on
plot(fm.freq_orig,padded_ap_fit,'--b')
hold on
plot(fm.freq_orig,padded_fooofed_spectrum,'r');
legend ({'Original spectrum','Aperiodic fit','Full model fit'});
xlabel('Frequency');
ylabel('logPower');
title('Model fit 2 - 40 Hz');
str1 = sprintf('r2 = %0.3f ',fm.r_squared);
str2 = sprintf('mae = %0.3f',fm.error(1));
text(ax,'Units', 'Normalized', 'Position', [0.05, 0.1],'String',{str1,str2});


ax = nexttile;
plot(fm.freq_orig,log10(fm.pow_orig),'k');
hold on
plot(fm.freq_orig, ap_fit_full,'--b')
hold on
plot(fm.freq_orig, fooofed_spectrum_full,'r');
legend ({'Original spectrum','Aperiodic fit','Full model fit'});
xlabel('Frequency');
ylabel('logPower');
title('Model fit 1 - 100 Hz');
str1 = sprintf('r2 = %0.3f ',r2);
str2 = sprintf('mae = %0.3f',mae);
text(ax,'Units', 'Normalized', 'Position', [0.05, 0.1],'String',{str1,str2});

% Log-log plot
fig = figure('Units','centimeters','Position',[14.4992    4.9530   33.8243   15.1765]);
plot(log10(fm.freq_orig),log10(fm.pow_orig),'k');
hold on
plot(log10(fm.freq_orig),fooofed_spectrum_full,'r');
hold on
plot(log10(fm.freq_orig),ap_fit_full,'--b')
legend ({'Original spectrum','Aperiodic fit','Full model fit'});
xlabel('logFrequency');
ylabel('logPower');
title(sprintf('Model %d - %d Hz, fitting 1 - 100 Hz',fm.freq_range(1),fm.freq_range(2)));
