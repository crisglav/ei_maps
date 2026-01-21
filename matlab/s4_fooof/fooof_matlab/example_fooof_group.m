% Fooof with groups of power spectra
% Script testing the reimplementation of fooof in Matlab
%
% Original python code by Tom Donoghue et. al in https://github.com/fooof-tools/fooof
%
% Cristina Gil Avila, TUM, 25.10.2023
close all
clear all
%% Loading demo data
power_path = '../../results/features/power/PFC/';
power_files = dir(fullfile(power_path,'*.mat'));
file = power_files(2);
load(fullfile(file.folder,file.name));

avgpow = mean(pow,1);

%% Fit fooof model
fm = fooof('freq_range',[2 40],'aperiodic_mode','knee');
% Add data to the model in the freq range 2 - 40 Hz (pre-specified)
fm = add_data(fm,freq,avgpow);
fm = fit(fm);
fm.get_results()

%% Fit fooofGroup model
% Initialize fooof object with some default settings
fg = fooofGroup('freq_range',[2 40],'aperiodic_mode','knee');
fg = add_data(fg,freq,pow);
fg = fit(fg);

% Get all the exponents
group_results = fg.group_results;
exps = cellfun(@(x) x.aperiodic_params(end), group_results)