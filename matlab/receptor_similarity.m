% Load schaefer positions
schaefer =  readtable('C:\Users\Cristina\nilearn_data\schaefer_2018\Schaefer2018_100Parcels_7Networks_order.txt');
% Extract network labels
schaefer_labels = schaefer{:,"Var2"};
rsn_mapping = cellfun(@(x) strsplit(x, '_'), schaefer_labels, 'UniformOutput', false);
rsn_mapping = cellfun(@(x) x{3}, rsn_mapping, 'UniformOutput', false);


% Load receptor data
receptor_data = readtable('C:\Users\Cristina\repos\hansen_receptors\results\receptor_data_scale100.csv');
receptor_data = table2array(receptor_data);

% zscore across receptors (columns), use population std -> make different
% receptors comparable
receptor_zscore = zscore(receptor_data,1,1);

% receptor similarity -> for each location, correlate receptors
sim = corrcoef(receptor_zscore');

% Rearrange receptor similarity by highest correlation
communities = unique(rsn_mapping);
inds = {}; % Rearranged indices
for icom =1:length(communities)
    mask = ismember(rsn_mapping, communities{icom});
    sim_com = sim(mask,mask);
    [~,idx] = sort(mean(sim_com,2),'descend');
    cco = find(mask);
    cco = cco(idx);
    inds{icom} = cco';
end
inds = [inds{:}];

% Plot similarity matrix reordered
figure;
imagesc(sim(inds,inds));

% % Sort communities 
% [sorted, ind] = sort(rsn_mapping);
% 
% % find the transitions between sorted communities (boundaries)
% bound = zeros(1,length(communities)-1);
% for icom =1:length(communities)-1
%     bound(icom) = find(diff(ismember(sorted, communities{icom})),1,'last');
% end
% bound = [1, bound, length(rsn_mapping)];
% 
% for ibound=1:length(bound)-1
%     i = ind(ibound:bound(ibound+1));
%     aux = sim(i,i);
% end
% 
% aux_mean = mean(aux,2);
% aux_mean_sorted = sort(aux_mean);