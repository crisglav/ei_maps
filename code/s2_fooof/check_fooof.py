#!/usr/bin/env python3
# This checks R2 model fit and imputes missing aperiodic exponents when possible.
# It also updates participants excel with a column fooofok.
#
# Cristina Gil Ávila, C3N, 27/08/2026

import os
import json
import logging
import numpy as np
import scipy.io as sio
import nibabel as nib
import time
import pickle
from fooof import FOOOFGroup
import pandas as pd


###############
# CONFIG
##############
config_file = os.path.join('..','config_megtusalen.json')
config = json.load(open(config_file))

# Project root
project_root = config['path']['project_root']

# Rsquared threshold to assess the goodness of fit of the modelled power spectrum
r2_thres = config['r2_thres']

# Cortical ROIS of the AAL2 altas
roi = np.asarray(config['roi'])

# Load atlas AAL template downsampled to source grid
template = sio.loadmat(os.path.join('..', '..', 'data', 'templates', 'template_AAL.mat'), squeeze_me=True, struct_as_record=False)
grid = template['grid']
area = np.asarray(getattr(grid, 'area')).astype(int)
cortical = np.isin(area, roi)
cortical_idx = np.where(cortical)[0]

# Load participants xlsx
participants = pd.read_excel(config['path']['participants'])

# List all fooof files from sesssions 1 and 2
fooofpathL1 = os.path.join(project_root, "L1", "data", "sources", "fooof_py")
fooofpathL2 = os.path.join(project_root, "L2", "data", "sources", "fooof_py")

files = []

for session, fooof_path in {
    "L1": fooofpathL1,
    "L2": fooofpathL2,
}.items():

    for filename in os.listdir(fooof_path):

        if filename.endswith(".mat"):

            files.append({
                "participant_id": filename.split("_")[0],
                "session": session,
                "path": os.path.join(fooof_path, filename)
            })


# Create participant_id + session keys
participant_keys = (
    participants["participant_id"].astype(str)
    + "_"
    + participants["session"].astype(str)
)

file_keys = [
    f"{file['participant_id']}_{file['session']}"
    for file in files
]

# Create lookup: participant_session -> file path
file_lookup = {
    key: file["path"]
    for key, file in zip(file_keys, files)
}

# Keep only participants with a corresponding file
is_included = participant_keys.isin(file_lookup)
participants = (
    participants.loc[is_included]
    .reset_index(drop=True)
)

# Reorder files to match participants
files = {
    key: file_lookup[key]
    for key in participant_keys[is_included]
}

# Safety check
ordered_file_ids = [
    os.path.basename(file).split("_")[0]
    for file in files
]
assert (
    ordered_file_ids
    == participants["participant_id"].astype(str).tolist()
), "Files and participants are not in the same order."


discard_subjects = []

for id, filepath in files.items():
    # with open(os.path.join( fooof_path, file), "rb") as f:
    #     fooofdata = pickle.load(f)
    # fg = fooofdata["fg"]
    #
    # # Extract fitted parameters
    # results = fg.get_results()
    #
    # # Get the aperiodic exponent
    # apexp_temp = np.array([
    #     res.aperiodic_params[-1] if res is not None else np.nan
    #     for res in results
    # ])
    #
    # # Embed cortical aperiodic exponents into flattened 3D grid
    # apexp = np.full(cortical.shape, np.nan, dtype=float)
    # apexp[cortical] = apexp_temp
    #
    # # Get R2
    # r2 = np.array([
    #     res.r_squared if res is not None else np.nan
    #     for res in results
    # ])

    fooofdata = sio.loadmat(filepath, squeeze_me=True, struct_as_record=False)
    subject = fooofdata['subject']
    task = fooofdata['task']
    channel = fooofdata['channel']

    # Get the aperiodic exponent
    apexp = fooofdata['apexp']

    # Get R2
    r2 = fooofdata['r_squared']

    # Extract bad model fits based on R2
    badfit = np.isnan(r2) | (r2 < r2_thres)

    # Set apexp to nan in case of bad fit
    apexp_imp = apexp.copy()
    cortical_apexp = apexp_imp[cortical]
    cortical_apexp[badfit] = np.nan
    apexp_imp[cortical] = cortical_apexp


    # If no bad model fit - continue with next subject
    if not(np.any(badfit)):
        continue

    print(f"{id} has missing values")

    # Else -> Loop over AAL rois to impute missing aperiodic exponents
    for iroi in roi:
        roi_mask = np.isin(area, iroi)
        apexp_roi = apexp_imp[roi_mask]

        # If the whole roi is missing - discard subject
        if all(np.isnan(apexp_roi)):
            discard_subjects.append(fooofdata['subject'])
            break

        # If there are missing values in this roi try to impute them
        if any(np.isnan(apexp_roi)):
            # If more than 50% of the positions of the roi are missing - discard subject
            per = np.sum(np.isnan(apexp_roi)) / len(apexp_roi)
            if per > 0.5:
                discard_subjects.append(fooofdata['subject'])
                break
            else:
            # Impute missing values for that roi with the roi's average
                mean_apexp = np.nanmean(apexp_roi)
                idx_roi = np.where(roi_mask)[0]
                apexp_imp[idx_roi[np.isnan(apexp_roi)]] = mean_apexp

    fooofdata["apexp_imp"] = apexp_imp

    # fooofdata = {
    #     "subject": subject,
    #     "task": task,
    #     "channel": channel,
    #     "apexp": apexp,
    #     "apexp_imp": apexp_imp,
    #     "r_squared": r2,
    #     "aperiodic_params": np.vstack([
    #         res.aperiodic_params if res is not None else np.full(2, np.nan)
    #         for res in results
    #     ]),
    # }

    # Save to disk
    outpath = os.path.join(os.path.dirname(filepath), f"{subject}_{task}_{channel}_fooof_sources_imp.mat")
    sio.savemat(outpath, fooofdata, do_compression=False)
print('done.')

# Update participants table
participants['fooofok'] = ~participants["participant_id"].isin(discard_subjects)
participants.to_excel(config['path']['participants'], index=False)