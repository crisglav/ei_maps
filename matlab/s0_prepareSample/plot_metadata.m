clear all
close all
clc

%% Load participants
participants = readtable('../../data/participants_real.xlsx');

participants.group = categorical(participants.group);
participants.sex   = categorical(participants.sex);
participants.diagnosis = categorical(participants.diagnosis);

%% Boxplot of age
figure;
boxplot(participants.age, participants.group);
ylabel('Age');
xlabel('Group');
title('Age by Group');

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