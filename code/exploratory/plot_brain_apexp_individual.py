# This script creates brainplots for group-averaged or dataset-averaged aperiodic exponents
#
# Cristina Gil Ávila, C3N, 31/08/2026

import os
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.io as sio
from neuromaps import resampling, images
from neuromaps.plotting import plot_surf_template
from nilearn.image import load_img, new_img_like, smooth_img
from nilearn import datasets, surface, plotting
import nibabel as nib
from datetime import datetime

# -----------------------
# Config
# -----------------------
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

# Project root (fooof files)
project_root = config['path']['project_root']
fooof_path = config['path']['fooof']

# Source grid, brain mask - ones at inside brain locations (2459)
parcellation_file = os.path.join('..', '..', 'data', 'templates', 'parcellation.nii')
parcellation_img = nib.load(parcellation_file)
brain_mask = parcellation_img.get_fdata() != 0

# Figures folder
figs_folder = os.path.join('..', '..', 'figs','brainmaps','apexp','individual')
os.makedirs(figs_folder, exist_ok=True)

# Participants file
participants_path = config['path']['participants']

# Dataset
dataset = ('FAM')

# Plot groups separately
plot_groups = True

# -----------------------
# Load participants metadata
# -----------------------
participants = pd.read_excel(participants_path)

# Select participants for this dataset
participants = participants[participants['participant_id'].astype(str).str.startswith(dataset)].copy()

# Discard participants with poor model fit
participants = participants[participants['fooofok']==True].copy()
print(f'Filtering: keeping {len(participants)} {dataset} participants')

# Create dictionary
participant_info = (participants.set_index('participant_id')[['diagnosis','session']].to_dict('index'))

# -----------------------
# Locate apexp files
# -----------------------
group_files = {pid:[] for pid in participants['participant_id'].unique()}

for pid, info in participant_info.items():
    group = info['diagnosis']
    session = info['session']

    apexp_folder = os.path.join(project_root, session, fooof_path)

    files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if f.endswith('imp.mat')
        and f.split('_')[0] == pid
    ]
    file = files[0] if files else None

    group_files[pid].append(file)

# -----------------------
# Plots
# -----------------------
for pid, files in list(group_files.items())[:5]:

    if not files:
        continue

    print(f'Processing {pid}')

    # Load apexp data (1D, Nsources)
    for apexp_file in files:
        fooofdata = sio.loadmat(apexp_file, squeeze_me=True, struct_as_record=False)
        apexp_data = fooofdata['apexp_imp']

    # Reshape into 3d grid (x,y,z) Use fortran order!
    apexp3d = apexp_data.reshape(np.shape(brain_mask), order='F')

    # Convert to nifti, use parcellation as template
    img = new_img_like(parcellation_img, apexp3d, copy_header=True)

    # Add smoothing for visualization
    img = smooth_img(img, fwhm=3)

    # Resample volumetric image to surface
    apexp_resampled, _ = resampling.resample_images(
        src=img,
        trg=img,
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
        # vmin=0,
        # vmax=1.1,
    )

    date = datetime.today().strftime('%Y%m%d')
    figname = f"brain_apexp_{dataset}_{pid}_{date}.png"

    plt.savefig(os.path.join(figs_folder, figname), dpi=300, transparent=True, bbox_inches='tight', pad_inches=0 )
    plt.close()
