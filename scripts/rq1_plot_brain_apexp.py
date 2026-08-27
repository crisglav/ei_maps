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
participants_path = os.path.join('..', 'data', 'participants_20260814.xlsx')
participants = pd.read_excel(participants_path)

# Only participants from the FAM project
participants = participants[
    participants["participant_id"]
    .astype(str)
    .str
    .startswith("FAM")
].copy()

# # Create column group merged
# participants["group_merged"] = participants["group"].replace({
#     "MCIa": "MCI",
#     "MCIm": "MCI",
#     "CONV": "AD",
#     "SCDpos": "SCD"
# })


# Dictionary: participant_id -> (group_merged, session)
participant_info = participants.set_index("participant_id")[["diagnosis", "session"]].to_dict("index")

all_files = []

# Search files for each participant in the correct session folder
for pid, info in participant_info.items():

    session = info["session"]
    apexp_folder = os.path.join(project_root, session, 'data', 'sources', 'fooof_py')

    # Find files that belong to this participant
    participant_files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if (f.endswith(".nii") or f.endswith(".nii.gz")) and f.split("_")[0] == pid
    ]

    all_files.extend(participant_files)

print(f"Found {len(all_files)} FAM files")

# Load files
images = [load_img(i) for i in all_files]

# Use first image as reference for affine/header/shape
ref_img = images[0]

# Load data and collect arrays
all_data = [img.get_fdata() for img in images]
stacked = np.stack(all_data, axis=-1)

# Mean across subjects/files, ignoring NaNs
mean_data = np.nanmean(stacked, axis=-1)

# Rebuild NIfTI image with original affine/header
fam_avg_img = new_img_like(ref_img, mean_data, copy_header=True)

# Add smoothing for visualization
fam_avg_img = smooth_img(fam_avg_img, fwhm=3)

# Resample to surface
apexp_resampled, _ = resampling.resample_images(
    src=fam_avg_img,
    trg=fam_avg_img,
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

# plt.suptitle('FAM average', fontsize=16, y=0.9)


figname = f"rq1_brain_apexp_FAM_cb.png"

plt.savefig(
    os.path.join(figs_folder, figname),
    dpi=300,
    transparent=True,
    bbox_inches='tight',
    pad_inches=0
)

plt.close()

