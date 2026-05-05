clear all

python = 'C:\Users\Cristina\megtusalen\L1\data\sources\fooof_py\';
new = 'C:\Users\Cristina\megtusalen\L1\data\sources\fooof\';

subject = 'FAM-084_rECpost_MEGMAG_fooof_sources.mat';

load([python subject],'apexp')
apexp_py = apexp';

load([new subject],'apexp')
apexp_1210 = apexp;

absTol = 1e-6;
relTol = 1e-3;

isDiff = ...
    (abs(apexp_1210 - apexp_py) > max(absTol, relTol .* max(abs(apexp_1210), abs(apexp_py)))) | ... % numeric difference
    (isnan(apexp_1210) ~= isnan(apexp_py));  % TRUE if one is NaN and the other is not

idx = find(isDiff);

sum(~isnan(apexp_py))
sum(~isnan(apexp_1210))