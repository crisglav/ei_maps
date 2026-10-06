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
import matplotlib.pyplot as plt
import statsmodels.api as sm

warnings.simplefilter('ignore', FutureWarning)

# -----------------------
# Config
# -----------------------
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

# Project root (fooof files)
project_root = config['path']['project_root']
fooof_path = config['path']['fooof']

# Participants path
participants_path = config['path']['participants']

# Receptors path
receptors_path = os.path.join('..', '..', 'data', 'prepared_receptors')

# Results path
results_path = os.path.join('..', '..', 'results')
os.makedirs(results_path, exist_ok=True)

# Figures folder
figs_folder = os.path.join('..', '..', 'figs','correlations')
os.makedirs(figs_folder, exist_ok=True)

# Parameters for statistical tests
parcellation_file = os.path.join('..', '..', 'data', 'templates', 'parcellation.nii')
n_perm = 1000
n_proc = 12
seed = 1234

# Dataset
dataset = ('FAM')

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
participant_info = (participants.set_index('participant_id')[['session']].to_dict('index'))

# -----------------------
# Brain mask and parcellation for spatial nulls
# -----------------------
parcellation_img = nib.load(parcellation_file)
brain_mask = parcellation_img.get_fdata() != 0

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

# Reorder receptors
receptor_order = [
    'NMDA',
    'mGluR5',
    'GABA_flumazenil',
    'GABA_a5',
    'ACh_a4b2',
    'ACh_M1'
]

resampled_receptors = {
    name: resampled_receptors[name]
    for name in receptor_order
}

# -----------------------
# Load individual apexp files and average across participants
# -----------------------
# Load apexp data (1D, Nsources)
apexp_data = []
for pid, apexp_file in apexp_files.items():
    fooofdata = sio.loadmat(apexp_file, squeeze_me=True, struct_as_record=False)
    apexp_data.append(fooofdata['apexp_imp'])

# Stack participants in the second dimension (Nsources x Nparticipants)
apexp_data = np.stack(apexp_data, axis=-1)

# Average across participants (Nsources, )
mean_apexp = np.nanmean(apexp_data, axis=-1)

# Zscore averaged aperiodic exponent
zdata = zscore(mean_apexp, nan_policy='omit')

# Reshape into 3d grid (x,y,z) Use fortran order!
zdata3d = zdata.reshape(np.shape(brain_mask), order='F')


# ------------------------
# Correlations
# ------------------------
results = {}
fig, axes = plt.subplots(6, 1, sharex=True, figsize=(2.5, 10))
# Loop over receptors
for ax, (receptor_name, receptor_img) in zip(axes, resampled_receptors.items()):

    # Extract receptor data in the brain mask
    receptor_data = images.load_data(receptor_img)
    receptor_data_masked = receptor_data[brain_mask]

    # Create a spatial null for this receptor
    print(f'\nComputing nulls for receptor: {receptor_name}')
    nulls_flat = nulls.burt2020(receptor_data_masked, atlas='mni152', density='2mm', parcellation=parcellation_img,
        n_perm=n_perm, n_proc=n_proc, seed=seed)

    # Embed spatial nulls into the 3D source grid
    nulls_4d = np.zeros(brain_mask.shape + (n_perm,), dtype=nulls_flat.dtype)
    nulls_4d[brain_mask, :] = nulls_flat

    # Spatial correlation with statistical test
    corr, pval = stats.compare_images(receptor_img, zdata3d, nulls=nulls_4d)

    # Store results
    results[receptor_name] = {
        'correlation': corr,
        'p_value': pval
    }

    print(f"{receptor_name} | R = {corr:.3f}, p = '{pval:.4g}")

    # Flatten again receptor data and apexp for visualization
    receptor_flat = receptor_data.flatten(order='F')
    apexp_flat = zdata.flatten(order='F')

    # --------------------
    # Scatter plot
    # --------------------
    ax.scatter(mean_apexp, receptor_flat,s=2,color='lightgray')
    ax.set_ylabel(receptor_name, fontname='Roboto', fontsize=10)

    x = sm.add_constant(pd.DataFrame({'apexp': mean_apexp}))
    y = receptor_flat

    # Linear model for this group
    model = sm.OLS(y, x, missing='drop').fit()
    print(model.summary())

    xfit = np.linspace(np.nanmin(mean_apexp), np.nanmax(mean_apexp), 100)
    xpred = pd.DataFrame({'const': 1, 'apexp': xfit})
    yfit = model.predict(xpred)

    # Linear fit plot
    if pval<0.05:
        color = '#F06292'
    else:
        color = 'gray'
    ax.plot(xfit, yfit, color=color,linewidth=1.5, label='_nolegend_')

    # R and pval
    if pval<0.001:
        txt = f'R = {corr:.2f}, p < 0.001'
    else:
        txt = f'R = {corr:.2f}, p = {pval:.3f}'

    ax.text(
        0.05, 0.95,
        txt,
        transform=ax.transAxes,
        ha='left',
        va='top',
        fontsize=10,
        fontname='Roboto'
    )

# Save figure
output_file = os.path.join(figs_folder, f'scatter_{dataset}_02102026.svg')
plt.savefig(output_file, dpi=300, transparent=True, bbox_inches='tight')
plt.close()
print(f'Saved figure: {output_file}')