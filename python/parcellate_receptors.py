# This script parcellates receptor maps to the AAL v2 SPM atlas and Schaefer 100 atlas

import os
import warnings

import numpy as np
from nilearn.datasets import fetch_atlas_aal, fetch_atlas_schaefer_2018
from neuromaps import datasets
from neuromaps.parcellate import Parcellater
from scipy.io import savemat
from scipy.stats import zscore

warnings.simplefilter("ignore", FutureWarning)

# -----------------------------------------------------------------------------
# Fetch atlas and receptor maps
# -----------------------------------------------------------------------------

# AAL v2 for SPM8, same as in MEG scripts
aal = fetch_atlas_aal(version='SPM8', data_dir=r'C:\Users\Cristina\nilearn_data')

# Schaefer 100 [arcels
schaefer = fetch_atlas_schaefer_2018(n_rois=100)

# Exclude cerebellum and vermis
aal_indices = np.array([int(i) for i in aal['indices']])
mask = aal_indices <= 9000

receptor_files = {
    "dubois": datasets.fetch_annotation(source='dubois2015', return_single=True),
    "galovic": datasets.fetch_annotation(source='galovic2021', return_single=True),
    "rosaneto": datasets.fetch_annotation(source='rosaneto', return_single=True),
    "smart": datasets.fetch_annotation(source='smart2019', return_single=True),
    "dukart": datasets.fetch_annotation(source='dukart2018', desc='flumazenil', return_single=True),
    "lukow": datasets.fetch_annotation(source='lukow2022', return_single=True),
    "norgaard": datasets.fetch_annotation(source='norgaard2021', space='MNI152', return_single=True),
}

# -----------------------------------------------------------------------------
# Parcellate to AAL SPM8
# -----------------------------------------------------------------------------
outpath = os.path.join('..', 'data', 'receptors', 'aal_spm8')
os.makedirs(outpath, exist_ok=True)

receptor_data = []
parcellater = Parcellater(aal['maps'], 'MNI152', resampling_target='parcellation')
for ref, receptor in receptor_files.items():
    parcellated = parcellater.fit_transform(receptor, 'MNI152')
    arr = np.asarray(parcellated).squeeze()

    # Apply mask (do not store cerebellum and vermis)
    arr = arr[mask]

    # Save individual receptor maps in a single .csv file
    outfile = os.path.join(outpath, ref + '.csv')
    np.savetxt(outfile, arr, delimiter=',')

    # Append to create a matrix of receptors
    receptor_data.append(arr)

receptor_data = np.column_stack(receptor_data)
reclabels = list(receptor_files.keys())

# Save full receptor matrix
savemat(os.path.join(outpath, 'rec_maps_aalspm8.mat'),{'receptors': receptor_data, 'labels': np.array(reclabels, dtype=object)})
np.savetxt(os.path.join(outpath, 'rec_maps_aalspm8.csv'),receptor_data,delimiter=',',header=','.join(reclabels))

# Perform a weighted average of the receptors of the same type
# Column mapping:
# 0 dubois
# 1 galovic
# 2 rosaneto
# 3 smart
# 4 dukart
# 5 lukow
# 6 norgaard
mGluR5 = (zscore(receptor_data[:, 0])*28 +
          zscore(receptor_data[:, 2])*22 +
          zscore(receptor_data[:, 3])*73) / (28+22+73)

nmda = receptor_data[:, 1]

gabaa = (zscore(receptor_data[:, 4])*6 +
         zscore(receptor_data[:, 5])*10 +
         zscore(receptor_data[:, 6])*16) / (6+10+16)

# Concatenate into a matrix (columns)
matrix = np.column_stack((mGluR5, nmda, gabaa))
wa_labels = ['mglur5', 'nmda', 'gabaa']

# Save weighted-average receptor matrix
savemat(os.path.join(outpath, 'rec_maps_wa_aalspm8.mat'),{'receptors_wa': matrix,'labels': np.array(wa_labels, dtype=object)})
np.savetxt(os.path.join(outpath, 'rec_maps_wa_aalspm8.csv'),matrix,delimiter=',', header=','.join(wa_labels))


# -----------------------------------------------------------------------------
# Parcellate to Schaefer-100
# -----------------------------------------------------------------------------
outpath = os.path.join('..', 'data', 'receptors', 'schaefer100')
os.makedirs(outpath, exist_ok=True)

receptor_data = []
parcellater = Parcellater(schaefer['maps'], 'MNI152')
for ref, receptor in receptor_files.items():
    parcellated = parcellater.fit_transform(receptor, 'MNI152')
    arr = np.asarray(parcellated).squeeze()

    # Append to create a matrix of receptors
    receptor_data.append(arr)

# Save matrix
receptor_data = np.column_stack(receptor_data)
reclabels = list(receptor_files.keys())
np.savetxt(os.path.join(outpath, 'rec_maps_schaefer100.csv'),receptor_data,delimiter=',',header=','.join(reclabels))
