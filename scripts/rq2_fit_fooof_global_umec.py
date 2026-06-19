#!/usr/bin/env python3

import os
import numpy as np
import pandas as pd
import scipy.io as sio
from fooof import FOOOF
import matplotlib.pyplot as plt
import pickle

# Project root
project_root = r'C:\Users\Cristina\megtusalen'

# FOOOF parameters
freq_range = [2, 45]
max_n_peaks = 100
peak_width_limits = [1, 12]
aperiodic_mode = 'fixed'

# Rsquared threshold to assess the goodness of fit of the modelled power spectrum
r2_thres = 0.85

# Cortical rois of the AAL atlas
roi = np.r_[np.arange(1, 41), np.arange(43, 71), np.arange(79, 91)]

# Load atlas AAL template downsampled to grid source
template = sio.loadmat(os.path.join('..','matlab','templates','template_AAL.mat'), squeeze_me=True, struct_as_record=False)
grid = template.get('grid')
area = getattr(grid,'area')
cortical = np.isin(area, roi)
cortical_idx = np.where(cortical)[0]

# Load participants file
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Select only participants from the UMEC project
mask = participants["participant_id"].astype(str).str.startswith("UMEC")
participants = participants[mask].copy()
participants.set_index('participant_id', inplace=True)

participant_info = participants[["diagnosis", "session"]].to_dict("index")

# List all power files
pow_files = {}

for pid, info in participant_info.items():
    session = info["session"]
    pow_path = os.path.join(project_root, session, 'data', 'sources', 'power')

    files = [ os.path.join (pow_path, f)
                  for f in os.listdir(pow_path)
                  if f.endswith('.mat') and f.startswith(pid)]

    pow_files[pid] = files[0] if files else None

# Add column to dataframe
participants["pow_path"] = participants.index.map(pow_files)

# Loop over groups
groups = participants["diagnosis"].unique()

rows = []

pow_group = {}
fm_subj = {}
fm_group = {}
# Loop over groups
for group in groups:
    fm_subj[group] = {}
    hits = participants["diagnosis"] == group
    group_participants = participants.loc[hits].copy()

    pow_this_group = []

    # Loop over participants in each group
    for participant_id, row in group_participants.iterrows():

        # Load power specta
        powdata = sio.loadmat(row["pow_path"], squeeze_me=True, struct_as_record=False)
        sources = getattr(powdata['band'],'sources')
        freq = getattr(sources,'freq')
        pow = getattr(sources,'pow')

        pow_this_group.append(pow)

        # Average across cortical sources
        pow_global = pow[cortical,:]
        pow_global = np.nanmean(pow_global, axis=0)

        # Fit fooof model for each individual
        fm = FOOOF(
            peak_width_limits=peak_width_limits,
            max_n_peaks=max_n_peaks,
            aperiodic_mode=aperiodic_mode,
            verbose=False,
        )
        fm.fit(freq, pow_global, freq_range=freq_range)
        fm_subj[group][participant_id] = fm

        # Format results in a dataframe
        rows.append({
            "participant_id": participant_id,
            "group": group,
            "apexp": fm.aperiodic_params_[1],
            "offset": fm.aperiodic_params_[0],
            "r2": fm.r_squared_,
            "error": fm.error_
        })


    # Concatenate PSDs: participants x sources x frequencies
    pow_this_group = np.stack(pow_this_group, axis=0)

    # Average across participants
    pow_grandavg = np.nanmean(pow_this_group, axis=0)

    # Average across cortical sources
    pow_global_group = pow_grandavg[cortical, :]
    pow_global_group = np.nanmean(pow_global_group, axis=0)
    pow_group[group] = pow_global_group


    # Fooof fitting at cortical sources
    fm = FOOOF(
        peak_width_limits=peak_width_limits,
        max_n_peaks=max_n_peaks,
        aperiodic_mode=aperiodic_mode,
        verbose=False,
    )
    fm.fit(freq, pow_global_group, freq_range=freq_range)
    fm_group[group] = fm

# Save to disk summary in a csv and full model fits with pkl
output_dir = os.path.join('..','results','fooof_global')
os.makedirs(output_dir, exist_ok=True)

fooof_subj_results = pd.DataFrame(rows)
fooof_subj_results.to_csv(os.path.join(output_dir,'UMEC_fooof_subj_results.csv'), index=False)

with open(os.path.join(output_dir,'UMEC_fm_subj.pkl'), "wb") as f:
    pickle.dump(fm_subj, f)

with open(os.path.join(output_dir,'UMEC_fm_group.pkl'), "wb") as f:
    pickle.dump(fm_group, f)
