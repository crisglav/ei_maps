receptor_data = readtable('C:\Users\Cristina\repos\hansen_receptors\results\receptor_data_scale100.csv');
receptor_data = table2array(receptor_data);

% zscore across receptors (columns), use population std -> make different
% receptors comparable
receptor_zscore = zscore(receptor_data,1,1);

% receptor similarity -> for each location, correlate each receptors
sim = corrcoef(receptor_zscore');

