% Script testing the reimplementation of fooof in Matlab
%
% Original python code by Tom Donoghue et. al in https://github.com/fooof-tools/fooof
%
% Cristina Gil Avila, TUM, 01.09.2023
close all
clear all

%% Load subset data and fooof it
power_path = '../../results/power/PFC/';
power_files = dir(fullfile(power_path,'*.mat'));
subset = power_files;
fooof_participants = cell(1,length(subset));

for iFile =1:length(subset)
    file = subset(iFile);
    load(fullfile(file.folder,file.name));

    % Average across channels
    avgpow = mean(pow,1);
    
    % Initialize a fooof object 
    fm = fooof('freq_range',[2 40]);
    
    % Add the data in the frequency range 2 - 40 Hz
    fm = add_data(fm,freq,avgpow);
    
    % Fit the model
    fm = fit(fm);

    fooof_participants{iFile} = fm;
end

%% Plotting
% Frequency range as specified
fig = figure('Units','centimeters','Position',[14.4992    4.9530   33.8243   15.1765]);
tlc = tiledlayout(2,3,'TileSpacing','Compact','Padding','Compact');
for iFile=1:length(subset)
    ax = nexttile;
    plot(fooof_participants{iFile}.freqs,fooof_participants{iFile}.power_spectrum,'k');
    hold on
    plot(fooof_participants{iFile}.freqs,fooof_participants{iFile}.fooofed_spectrum,'r');
    hold on
    plot(fooof_participants{iFile}.freqs,fooof_participants{iFile}.ap_fit,'--b')
    % legend ({'Original spectrum','Aperiodic fit','Full model fit'});
    xlabel('Frequency');
    ylabel('logPower');
    str = strsplit(subset(iFile).name,'_');
    title(str{1});
    str1 = sprintf('r2 = %0.3f ',fooof_participants{iFile}.r2);
    str2 = sprintf('mae = %0.3f',fooof_participants{iFile}.error_mae);
    text(ax,'Units', 'Normalized', 'Position', [0.05, 0.1],'String',{str1,str2});

end
title(tlc,sprintf('Model %d - %d Hz',fm.freq_range(1),fm.freq_range(2)));
