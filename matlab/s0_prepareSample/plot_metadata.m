clear all
close all
clc

%% Load participants
participants = readtable('../../data/participants_real.xlsx');

participants.group = categorical (participants.group);
participants.diagnosis = categorical (participants.diagnosis);
participants.sex = categorical (participants.sex);
participants.group_merged = participants.group;

% Recode values
participants.group_merged(ismember(participants.group, ["MCIa","MCIm"])) = "MCI";
participants.group_merged(participants.group == "CONV") = "AD";

% Convert to categorical (optional but recommended)
participants.group_merged = categorical(participants.group_merged);


%% Boxplot of age
figure;
boxplot(participants.age, participants.group_merged, 'GroupOrder', {'FHneg','FHpos','SCDneg','SCDpos','MCIneg','MCI','AD'});
ylabel('Age');
xlabel('Group');
title('Age by Group');

%% ANOVA on age
excludeGroups = {};

participants_ = participants( ...
    ~ismember(cellstr(participants.group_merged), excludeGroups), :);

% Remove unused categorical levels
participants_.group_merged = removecats(participants_.group_merged);

% ANOVA
[p, tbl, stats] = anova1( ...
    participants_.age, ...
    participants_.group_merged);

[c, m, h, gnames] = multcompare(stats);

% c columns:
% 1 = group 1 index
% 2 = group 2 index
% 3 = lower CI
% 4 = mean difference
% 5 = upper CI
% 6 = adjusted p-value

posthoc_table = array2table(c, ...
    'VariableNames', {'Group1_idx','Group2_idx','LowerCI','MeanDiff','UpperCI','p_adj'});

posthoc_table.Group1 = gnames(posthoc_table.Group1_idx);
posthoc_table.Group2 = gnames(posthoc_table.Group2_idx);

posthoc_table = movevars(posthoc_table, ...
    {'Group1','Group2'}, ...
    'Before', 'Group1_idx');

disp(posthoc_table)

%% Barplot of sex distribution by group

groupCats = categories(participants.group);
sexCats   = categories(participants.sex);

countMat = zeros(numel(groupCats), numel(sexCats));

for ig = 1:numel(groupCats)
    idxG = participants.group == groupCats{ig};
    
    for is = 1:numel(sexCats)
        countMat(ig,is) = sum(participants.sex(idxG) == sexCats{is});
    end
end

figure;
bar(countMat, 'grouped');
set(gca,'XTickLabel', groupCats);
xlabel('Group');
ylabel('Count');
legend(sexCats, 'Location', 'best');
title('Sex distribution by group');