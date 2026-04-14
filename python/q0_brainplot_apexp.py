# This script creates brainplots for group-averaged aperiodic exponents

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from neuromaps import resampling, images
from neuromaps.plotting import plot_surf_template

from nilearn.image import mean_img, smooth_img
from nilearn import datasets, surface, plotting

# Path to project root
project_root = r'C:\Users\Cristina\megtusalen'

# Figures folder
figs_folder = os.path.join('..', 'figs','brainmaps')
os.makedirs(figs_folder, exist_ok=True)

# Load participants file
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Create column group merged
participants["group_merged"] = participants["group"].replace({
    "MCIa": "MCI",
    "MCIm": "MCI",
    "CONV": "AD",
    "SCDpos": "SCD"
})

# Set groups
groups = participants["group_merged"].unique()

# Dictionary: participant_id -> (group_merged, session)
participant_info = participants.set_index("participant_id")[["group_merged", "session"]].to_dict("index")

# Initialize dictionary to store files for each group
group_files = {g: [] for g in groups}

# Search files for each participant in the correct session folder
for pid, info in participant_info.items():
    group = info["group_merged"]
    session = info["session"]

    apexp_folder = os.path.join(project_root, session, 'data', 'sources', 'apexp')

    # Find files that belong to this participant
    participant_files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if (f.endswith(".nii") or f.endswith(".nii.gz")) and f.split("_")[0] == pid
    ]

    group_files[group].extend(participant_files)


# Loop through groups and compute average image
for group, files in group_files.items():

    # Average across all files belonging to that group
    group_avg_img = mean_img(files, copy_header=True)

    # Add smoothing for visualization
    group_avg_img = smooth_img(group_avg_img, fwhm=5)

    # Resample to surface
    apexp_resampled, _ = resampling.resample_images(
        src=group_avg_img,
        trg=group_avg_img,
        src_space='MNI152',
        trg_space='MNI152',
        resampling='transform_to_alt',
        alt_spec=('fsaverage', '10k')
    )

    # Plot
    plot_surf_template(
        apexp_resampled,
        template='fsaverage',
        density='10k',
        surf='inflated',
        mask_medial=True,
        colorbar=True,
        vmin=0,
        vmax=1,
    )

    plt.suptitle(group, fontsize=16, y=0.9)
    plt.savefig(
        os.path.join(figs_folder, f"apexp_dist_{group}_aux.png"),
        dpi=300,
        transparent=True,
        bbox_inches='tight',
        pad_inches=0
    )
    plt.close()

