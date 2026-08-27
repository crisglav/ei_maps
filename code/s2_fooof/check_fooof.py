#!/usr/bin/env python3
# This script parametrizes power spectra at each source position with fooof algorithm.
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

sessions = ["L1", "L2"]
discard_subjects = []

# Loop over sessions
for session in sessions:
    # fooof_path = os.path.join(project_root, session, config['path']['fooof'])
    fooof_path = os.path.join(project_root, session, "data", "sources", "fooof_py")

    # # List fooof files
    # files = sorted(
    #     f for f in os.listdir(fooof_path)
    #     if f.endswith(".pkl")
    # )

    files = sorted(
        f for f in os.listdir(fooof_path)
        if f.endswith(".mat")
    )

    for file in files:
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

        filepath = os.path.join(fooof_path, file)
        fooofdata = sio.loadmat(filepath, squeeze_me=True, struct_as_record=False)

        # Get the aperiodic exponent
        apexp = fooofdata['apexp']

        # Get R2
        r2 = fooofdata['r_squared']

        # Preallocate apexp_imp
        apexp_imp = apexp.copy()

        # Extract bad model fits based on R2
        badfit = r2 < r2_thres

        # If no bad model fit - continue with next subject
        if not(np.any(badfit)):
            continue

        # Else -> Loop over AAL rois to impute missing aperiodic exponents
        for iroi in roi:
            roi_mask = np.isin(area, iroi)
            apexp_roi = apexp[roi_mask]

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





        # Impute aperiodic exponent to AAL rois which are missing some apexp value.
        #
        # # Set to nan aperiodic exponents whose model fit is lower than a threshold
        # apexp_clean = apexp.copy()
        # cortical_apexp = apexp_clean[cortical]
        # badfit = r2 < r2_thres
        #
        # cortical_apexp[badfit] = np.nan
        # apexp_clean[cortical] = cortical_apexp


        # fooofdata = {
        #     "subject": subject,
        #     "task": task,
        #     "channel": channel,
        #     "whitener": powdata.get("whitener", None),
        #     "lambda": powdata.get("lambda", None),
        #     "taper": powdata.get("taper", None),
        #     "apexp": apexp,
        #     "apexp_imp": apexp_imp,
        #     "r_squared": r2,
        #     "aperiodic_params": np.vstack([
        #         res.aperiodic_params if res is not None else np.full(2, np.nan)
        #         for res in results
        #     ]),
        # }
        #
        # # Save to disk
        # outpath = os.path.join(fooof_path, f"{subject}_{task}_{channel}_fooof_sources_imp.mat")
        # sio.savemat(outpath, fooofdata, do_compression=False)
print('done.')
