#!/usr/bin/env python3

import os
import numpy as np
import pandas as pd
import scipy.io as sio
from fooof import FOOOF
import matplotlib.pyplot as plt

def save_apexp_nifti(apexp, grid, outname):

    dim = np.asarray(get_field(grid, "dim"), dtype=int)
    img_data = np.asarray(apexp, dtype=np.float32).reshape(dim, order='F')

    # hard coded affine
    affine = np.array([
        [10.0, 0.0, 0.0, -70.0],
        [0.0, 10.0, 0.0, -110.0],
        [0.0, 0.0, 10.0, -70.0],
        [0.0, 0.0, 0.0, 1.0]
    ], dtype=float)

    nii = nib.Nifti1Image(img_data, affine)

    nii.header.set_xyzt_units('mm')

    nib.save(nii, outname + ".nii.gz")



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

# Omit participants from FAM dataset
mask = ~participants["participant_id"].astype(str).str.startswith("FAM")
participants = participants[mask].copy()
participants.set_index('participant_id', inplace=True)

# # Create column group merged
# participants["group_merged"] = participants["group"].replace({
#     "MCIa": "MCI",
#     "MCIm": "MCI",
#     "CONV": "AD",
#     "SCDpos": "SCD"
# })
#
# # Dictionary: participant_id -> (group_merged, session)
# participant_info = participants[["group_merged", "session"]].to_dict("index")
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
# groups = participants["group_merged"].unique()
groups = participants["diagnosis"].unique()

avg_pow = {}
fooof_models = {}
apexp = {}

for group in groups:
    # hits = participants["group_merged"] == group
    hits = participants["diagnosis"] == group
    group_participants = participants.loc[hits].copy()

    pow_group = []

    for _, row in group_participants.iterrows():

        powdata = sio.loadmat(row["pow_path"], squeeze_me=True, struct_as_record=False)

        sources = getattr(powdata['band'],'sources')

        freq = getattr(sources,'freq')
        pow = getattr(sources,'pow')

        pow_group.append(pow)

    # shape: participants x sources x frequencies
    pow_group = np.stack(pow_group, axis=0)

    # Average across participants
    mean_power = np.nanmean(pow_group, axis=0)
    avg_pow[group] = mean_power

    # Extract power at cortical sources
    cortical_power = mean_power[cortical, :]

    # Average across cortex
    avg_cort_pow = np.nanmean(cortical_power, axis=0)

    # Fooof fitting at cortical sources
    fm = FOOOF(
        peak_width_limits=peak_width_limits,
        max_n_peaks=max_n_peaks,
        aperiodic_mode=aperiodic_mode,
        verbose=False,
    )
    fm.fit(freq, avg_cort_pow, freq_range=freq_range)
    fooof_models[group] = fm

    # Aperiodic exponent
    apexp[group] = fm.aperiodic_params_[1]


# Plotting
# group_colors = {
#     # "FHneg":   "#1F77B4",  # blue
#     # "FHpos":   "#6BAED6",  # light blue
#     "MCIneg":  "#1B5E20",  # dark green
#     "SCDneg":  "#43A047",  # green
#     "SCD":     "#FDD835",  # yellow
#     "MCI":     "#FB8C00",  # red-orange
#     "AD":      "#8B0000",  # dark red
# }

group_colors = {
    "HC":      "#43A047",  # green
    "SCD":     "#FDD835",  # yellow
    "MCI":     "#FB8C00",  # red-orange
    "AD":      "#8B0000",  # dark red
}

for group, color in group_colors.items():

    fm = fooof_models[group]

    plt.plot(fm.freqs, fm.power_spectrum, color=color, alpha=0.6, linewidth=2, label = group)
    plt.plot(fm.freqs, fm._ap_fit, color=color, linestyle="--", linewidth=2)

plt.xscale('log')
plt.xlabel("Frequency (Hz)")
plt.ylabel("Log Power")
plt.title("Group-average spectra and aperiodic fits")
plt.legend()
plt.tight_layout()
plt.show()



