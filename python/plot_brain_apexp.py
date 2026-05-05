# This script creates brainplots for group-averaged aperiodic exponents

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from neuromaps import resampling, images
from neuromaps.plotting import plot_surf_template

from nilearn.image import load_img, new_img_like, smooth_img
from nilearn import datasets, surface, plotting

import nibabel as nib

# Path to project root
project_root = r'C:\Users\Cristina\megtusalen'

# Figures folder
figs_folder = os.path.join('..', 'figs','brainmaps','apexp')
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
groups = ['FHneg','FHpos','SCDneg','MCIneg','SCD','MCI','AD']

# Dictionary: participant_id -> (group_merged, session)
participant_info = participants.set_index("participant_id")[["group_merged", "session"]].to_dict("index")

# Initialize dictionary to store files for each group
group_files = {g: [] for g in groups}

# Search files for each participant in the correct session folder
for pid, info in participant_info.items():
    group = info["group_merged"]
    session = info["session"]

    apexp_folder = os.path.join(project_root, session, 'data', 'sources', 'fooof_py')

    # Find files that belong to this participant
    participant_files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if (f.endswith(".nii") or f.endswith(".nii.gz")) and f.split("_")[0] == pid
    ]

    group_files[group].extend(participant_files)


# Loop through groups and compute average image
for group, files in group_files.items():

    # Load files
    images = [load_img(i) for i in files]

    # Use first image as reference for affine/header/shape
    ref_img = images[0]

    # Load data and collect arrays
    all_data = [img.get_fdata() for img in images]

    # Stack images into shape: (x, y, z, n_images)
    stacked = np.stack(all_data, axis=-1)

    # Mean across subjects/files, ignoring NaNs
    mean_data = np.nanmean(stacked, axis=-1)
    sem_data = np.nanstd(stacked, axis=-1)/np.sqrt(stacked.shape[-1])

    # Rebuild NIfTI image with original affine/header
    group_avg_img = new_img_like(ref_img, mean_data, copy_header=True)
    group_sem_img = new_img_like(ref_img, sem_data, copy_header=True)

    # Add smoothing for visualization
    group_avg_img = smooth_img(group_avg_img, fwhm=3)
    group_sem_img = smooth_img(group_sem_img, fwhm=3)

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
        # colorbar=True,
        vmin=0,
        vmax=1,
    )

    plt.suptitle(group, fontsize=16, y=0.9)


    figname = f"py_apexp_{group}.png"

    plt.savefig(
        os.path.join(figs_folder, figname),
        dpi=300,
        transparent=True,
        bbox_inches='tight',
        pad_inches=0
    )

    # SEM
    # Resample to surface
    # sem_resampled, _ = resampling.resample_images(
    #     src=group_sem_img,
    #     trg=group_sem_img,
    #     src_space='MNI152',
    #     trg_space='MNI152',
    #     resampling='transform_to_alt',
    #     alt_spec=('fsaverage', '10k')
    # )

    # plot_surf_template(
    #     sem_resampled,
    #     template='fsaverage',
    #     density='10k',
    #     surf='inflated',
    #     mask_medial=True,
    #     colorbar=True,
    # )
    #
    # plt.suptitle(f"SEM_{group}", fontsize=16, y=0.9)
    #
    # if mask_cortex:
    #     figname = f"sem_{group}_cortical.png"
    # else:
    #     figname = f"sem_{group}.png"
    #
    # plt.savefig(
    #     os.path.join(figs_folder, figname),
    #     dpi=300,
    #     transparent=True,
    #     bbox_inches='tight',
    #     pad_inches=0
    # )

    plt.close()

