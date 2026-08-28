function [participants, apexp_all, subject_mask] = deal_nans_apexp(config, participants, apexp_all)
% Impute apexp to rois which are missing some apexp value. Fill missing values for that roi with
% the mean of that roi. If all values of a roi
% are missing the participant will be discarded from the statistical
% analysis.

% Loads the template.
template         = load ( config.template );
cortical_mask = ismember(template.grid.area,config.roi);

discard_subjects = [];

% Goes though each subject.
for isubj = 1: size ( apexp_all, 1 )

    % apexp
    apexp = apexp_all(isubj,:);
    apexp_cortical = apexp(cortical_mask);

    if any(isnan(apexp_cortical))
        fprintf('%d, %s has missing values\n', isubj, participants.participant_id{isubj});
    else
        continue
    end

    % Goes through each roi
    for iroi = 1:numel(config.roi)

        roi_mask = template.grid.area == config.roi(iroi);
        apexp_roi = apexp(roi_mask);

        % Discard subjects who are missing a whole roi
        if all(isnan(apexp_roi))
            % warning('All nans in findex %-3d | roi %-2d | roi size %-2d',findex, iroi, sum(roi_mask));
            discard_subjects = [discard_subjects isubj];
            break
        end

        % Check the percentage of sources of the roi that are missing.
        if any(isnan(apexp_roi))

            nanpos = isnan(apexp_roi);
            pernan = (sum(nanpos) / sum(roi_mask));
            % warning('findex %-3d | roi %-2d | roi size %-2d | percentage nan %-5.1f',findex, iroi, sum(roi_mask), pernan);

            % If more than 50% of positions missing discard subject.
            if pernan > 0.5
                % warning('Participant will be discarded: findex %-3d | roi %-2d | roi size %-2d | percentage nan %-5.1f',findex, iroi, sum(roi_mask), pernan);
                discard_subjects = [discard_subjects isubj];
                break
            else

                % Impute aperiodic exponent with the mean of the roi
                mean_apexp = mean(apexp(roi_mask),'omitnan');
                idx_roi = find(roi_mask);
                apexp(idx_roi(nanpos)) = mean_apexp;

            end

        end

    end

    apexp_all(isubj,:) = apexp;

end
discard_subjects = unique(discard_subjects);
subject_mask = true(height(participants),1);
subject_mask(discard_subjects) = false;

% Discard subjects
participants = participants(subject_mask,:);
apexp_all = apexp_all(subject_mask,:);
end