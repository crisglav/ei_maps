# Fit fooof on the global power spectrum (averaged across all sources) for dataset 1 (FAM)
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
participants_path = os.path.join('..', 'data', 'participants_real_20260717.xlsx')
participants = pd.read_excel(participants_path)

# Select only participants from the FAM project
mask = participants["participant_id"].astype(str).str.startswith("FAM")
participants = participants[mask].copy()
participants.set_index('participant_id', inplace=True)

participant_info = participants.to_dict("index")

# List all power files
pow_files = {}
pow_path = os.path.join(project_root, 'L1', 'data', 'sources', 'power')

for pid, _ in participant_info.items():
    files = [ os.path.join (pow_path, f)
                  for f in os.listdir(pow_path)
                  if f.endswith('.mat') and f.startswith(pid)]

    pow_files[pid] = files[0] if files else None

participants["pow_path"] = participants.index.map(pow_files)

# Load power files
pow_all = []
for participant_id, row in participants.iterrows():

    # Load power specta
    powdata = sio.loadmat(row["pow_path"], squeeze_me=True, struct_as_record=False)
    sources = getattr(powdata['band'],'sources')
    freq = getattr(sources,'freq')
    pow = getattr(sources,'pow')

    pow_all.append(pow)

 # Concatenate PSDs: participants x sources x frequencies
pow_all = np.stack(pow_all, axis=0)

# Average across cortical sources
pow_global = pow_all[:,cortical, :]
pow_global = np.nanmean(pow_global, axis=1)

# Average across participants
pow_global_grandavg = np.nanmean(pow_global, axis=0)

# Fooof fitting at cortical sources
fm = FOOOF(
    peak_width_limits=peak_width_limits,
    max_n_peaks=max_n_peaks,
    aperiodic_mode=aperiodic_mode,
    verbose=False,
)
fm.fit(freq, pow_global_grandavg, freq_range=freq_range)

# Save to disk summary
output_dir = os.path.join('..','results','fooof_global')
with open(os.path.join(output_dir,'FAM_fm_grandavg.pkl'), "wb") as f:
    pickle.dump(fm, f)
