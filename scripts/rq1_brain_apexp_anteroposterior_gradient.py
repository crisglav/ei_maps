# This script creates brainplots for group-averaged aperiodic exponents

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from neuromaps import resampling, images
from neuromaps.plotting import plot_surf_template

from nilearn.image import load_img
from scipy.stats import ttest_1samp


import nibabel as nib

# Path to project root
project_root = r'C:\Users\Cristina\megtusalen'

# Figures folder
figs_folder = os.path.join('..', 'figs','brainmaps','apexp')
os.makedirs(figs_folder, exist_ok=True)

# Load participants file
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Only participants from the FAM project
participants = participants[
    participants["participant_id"]
    .astype(str)
    .str
    .startswith("FAM")
].copy()

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


# Load files
images = [load_img(i) for i in all_files]

from scipy.stats import pearsonr

# Group-average map
avg_data = np.mean(
    np.stack([img.get_fdata() for img in images], axis=0),
    axis=0
)

valid = np.isfinite(avg_data)

ijk = np.array(np.where(valid)).T
xyz = nib.affines.apply_affine(images[0].affine, ijk)

apexp = avg_data[valid]

xcoord = xyz[:,0]
ycoord = xyz[:,1]
zcoord = xyz[:,2]

fig, axes = plt.subplots(1, 3, figsize=(12, 4))

for ax, coord, label in zip(
    axes,
    [xcoord, ycoord, zcoord],
    ["X (Left-Right)", "Y (Posterior-Anterior)", "Z (Inferior-Superior)"]
):

    r, p = pearsonr(coord, apexp)

    ax.scatter(
        coord,
        apexp,
        s=5,
        alpha=0.2
    )

    coef = np.polyfit(coord, apexp, 1)
    xfit = np.linspace(coord.min(), coord.max(), 100)

    ax.plot(
        xfit,
        np.polyval(coef, xfit),
        linewidth=2
    )

    ax.set_title(f"r={r:.2f}, p={p:.2e}")
    ax.set_xlabel(label)
    ax.set_ylabel("Aperiodic exponent")

plt.tight_layout()
plt.show()
