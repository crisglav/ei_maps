# This script creates brainplots for group-averaged aperiodic exponents
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
figs_folder = os.path.join('..', '..', 'figs','brainmaps','apexp')
os.makedirs(figs_folder, exist_ok=True)

# Participants file
participants_path = config['path']['participants']

# Dataset
dataset = ('FAM')

# Plot groups separately
plot_groups = False

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
if plot_groups:
    # Initialize dictionary to store files for each group
    group_files = {group:[] for group in participants['diagnosis'].unique()}

else:
    group_files = {'all':[]}

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

    if plot_groups:
        group_files[group].append(file)
    else:
        group_files['all'].append(file)

# -----------------------
# Plots
# -----------------------
for group, files in group_files.items():
    # FIX

    if not files:
        continue

    print(f'Processing {group}: {len(files)} files')

    # Load apexp data (1D, Nsources)
    apexp_data = []
    for apexp_file in files:
        fooofdata = sio.loadmat(apexp_file, squeeze_me=True, struct_as_record=False)
        apexp_data.append(fooofdata['apexp_imp'])

    # Stack participants in the fourth dimension (Nsources x Nparticipants)
    apexp_data = np.stack(apexp_data, axis=-1)

    # Average across participants (Nsources, )
    mean_apexp = np.nanmean(apexp_data, axis=-1)

    # Reshape into 3d grid (x,y,z) Use fortran order!
    mean_apexp3d = mean_apexp.reshape(np.shape(brain_mask), order='F')

    # Convert to nifti, use parcellation as template
    mean_img = new_img_like(parcellation_img, mean_apexp3d, copy_header=True)

    # Add smoothing for visualization
    mean_img = smooth_img(mean_img, fwhm=3)

    # Resample volumetric image to surface
    apexp_resampled, _ = resampling.resample_images(
        src=mean_img,
        trg=mean_img,
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

    date = datetime.today().strftime('%Y%m%d')
    figname = f"brain_apexp_{dataset}_{group}_{date}.png"

    plt.savefig(os.path.join(figs_folder, figname), dpi=300, transparent=True, bbox_inches='tight', pad_inches=0 )
    plt.close()
