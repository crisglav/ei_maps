clear all
close all

% Relabel atlas rois to match previous labels
new_atlas = load ("FS average - myAAL.mat");
new_labels = new_atlas.atlas.name;
old_atlas = load ("template_AAL.mat");
old_labels = old_atlas.atlas.name;

t = table(old_labels, 'VariableNames',{'old_labels'})
writetable(t,'old_labels.xls');

t = table(new_labels, 'VariableNames',{'new_labels'})
writetable(t,'new_labels.xls');
