clear all
close all
clc

project_root  = 'C:\Users\Cristina\megtusalen';

%% PARTICIPANTS SAMPLE EXCEL
% Load participant sample
participants = readtable('../../data/participant_sample.xlsx');
participants.group_simp = categorical (participants.group_simp);
participants.project = categorical (participants.project);
participants.sex = categorical (participants.sex);

% Get participants with source level data, that are healthy, and have a
% diagnosis (N = 569)
mask = participants.missing_lcmv == 0 & participants.not_healthy == 0 & ~isundefined(participants.group_simp);
sample = participants(mask,:);

%% Plot age histograms per group
groups = {'AD','MCI','SCD','FH','HC'};
edges = 35:1:90;

figure;
hold on
for ig=1:length(groups)

    group = sample.group_simp == groups{ig};
    age_group = sample.age(group);
    histogram(age_group,edges,'FaceAlpha',0.6);
end
legend(groups)

%% Boxplots of age
figure;
boxplot(sample.age,sample.group_simp);
ylabel('Age');
xlabel('Group');


%% Barplots sex
sexCats = categories(sample.sex); 

countMat = zeros(numel(groups), numel(sexCats));
for ig = 1:numel(groups)
    idxG = sample.group_simp == groups{ig};
    for is = 1:numel(sexCats)
        countMat(ig,is) = sum(sample.sex(idxG) == sexCats{is});
    end
end

figure;
bar(countMat, 'grouped');
set(gca,'XTickLabel', groups);
xlabel('Group');
ylabel('Count');
legend(sexKeep, 'Location','best');
title('Sex distribution by group');