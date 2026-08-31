# This scripts correlates individual aperiodic exponents to six neurotransmitter receptor maps.
# We perform a spatial correlations with non-parametric statistical tests using spatial nulls from Burt et al 2020
#
# Cristina Gil Ávila, C3N, 31/08/2026

import os
import warnings
import json
import nibabel as nib
import numpy as np
import pandas as pd
import scipy.io as sio
from scipy.stats import zscore
from neuromaps import stats, images, nulls

warnings.simplefilter('ignore', FutureWarning)

# -----------------------
# Config
# -----------------------
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

# Project root (fooof files)
project_root = config['path']['project_root']
fooof_path = config['path']['fooof']

# Receptors path
receptors_path = os.path.join('..', '..', 'data', 'prepared_receptors')

# Participants path
participants_path = os.path.join('..', '..', 'data', 'participants', 'participants_20260814.xlsx')

# Results path
results_path = os.path.join('..', '..', 'results')
os.makedirs(results_path, exist_ok=True)

# Parameters for statistical tests
parcellation_file = os.path.join('..', '..', 'data', 'templates', 'parcellation.nii')
n_perm = 1000
n_proc = 12
seed = 1234

# Dataset
dataset = ('UMEC')

# -----------------------
# Load participants metadata
# -----------------------
participants = pd.read_excel(participants_path)

# Select participants for this dataset
participants = participants[participants['participant_id'].astype(str).str.startswith(dataset)].copy()
print(f'Filtering: keeping {len(participants)} {dataset} participants')

# Create dictionary
participant_info = (participants.set_index('participant_id')[['session']].to_dict('index'))

# -----------------------
# Locate apexp files
# -----------------------
apexp_files = {}

for pid, info in participant_info.items():
    session = info['session']

    apexp_folder = os.path.join(project_root, session, fooof_path)

    files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if f.endswith('imp.mat')
        and f.split('_')[0] == pid
    ]

    apexp_files[pid] = files[0] if files else None


# -----------------------
# Load receptors
# -----------------------
resampled_receptors = {}
for fname in os.listdir(receptors_path):
    if fname.endswith('.nii') or fname.endswith('.nii.gz'):
        name = fname.replace('.nii.gz', '').replace('.nii', '')
        path = os.path.join(receptors_path, fname)
        resampled_receptors[name] = nib.load(path)

print(f'Loaded {len(resampled_receptors)} receptors')

# -----------------------
# Brain mask and parcellation for spatial nulls
# -----------------------
parcellation_img = nib.load(parcellation_file)
brain_mask = parcellation_img.get_fdata() != 0

# ------------------------
# Correlations
# ------------------------
results = {
    pid: {'participant_id': pid}
    for pid in participants['participant_id']
}

# Loop over receptors
for receptor_name, receptor_img in resampled_receptors.items():

    # Extract receptor data in the brain mask
    receptor_data = images.load_data(receptor_img)
    receptor_data = receptor_data[brain_mask]

    # Create a spatial null for this receptor
    print(f'\nComputing nulls for receptor: {receptor_name}')
    nulls_flat = nulls.burt2020(receptor_data, atlas='mni152', density='2mm', parcellation=parcellation_img,
        n_perm=n_perm, n_proc=n_proc, seed=seed)

    # Embed spatial nulls into the 3D source grid
    nulls_4d = np.zeros(brain_mask.shape + (n_perm,), dtype=nulls_flat.dtype)
    nulls_4d[brain_mask, :] = nulls_flat

    # Loop over subjects
    for pid, apexp_file in apexp_files.items():

        print(f'Processing subject {pid} | receptor {receptor_name}')

        corr_key = f'corr_{receptor_name}'
        pval_key = f'pval_{receptor_name}'

        if apexp_file is None:
            results[pid][corr_key] = np.nan
            results[pid][pval_key] = np.nan
            continue

        try:
            # Load apexp data (cortical sources)
            fooofdata = sio.loadmat(apexp_file, squeeze_me=True, struct_as_record=False)
            apexp_data = fooofdata['apexp_imp']

            # Z-score apexp, and reshape to 3d grid using matlab order
            zdata = zscore(apexp_data, nan_policy='omit')
            zdata3d = zdata.reshape(np.shape(brain_mask), order='F')

            # Spatial correlation with statistical test
            corr, pval = stats.compare_images( receptor_img, zdata3d, nulls=nulls_4d)

            # Save R value and p value
            results[pid][corr_key] = corr
            results[pid][pval_key] = pval

        except Exception as e:
            print(f'Error: {pid} | {receptor_name} -> {e}')
            results[pid][corr_key] = np.nan
            results[pid][pval_key] = np.nan

# -----------------------
# Save results
# -----------------------
output_file = os.path.join(results_path, f'corr_apexp_receptors_{dataset}_20260831.csv')

corr_df = pd.DataFrame(results.values())
corr_df.to_csv(output_file, index=False)

print(f'\nResults saved to: {output_file}')