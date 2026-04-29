# This script parcellates receptor maps to the AAL v2 SPM atlas

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
idx = np.array(aal['indices'], dtype=int)
labels = np.array(aal['labels'])
noncortical = {'Amygdala_L', 'Amygdala_R', 'Caudate_L', 'Caudate_R', 'Putamen_L', 'Putamen_R', 'Pallidum_L', 'Pallidum_R', 'Thalamus_L', 'Thalamus_R'}
# Exclude cerebellum, vermis (idx < 9000) and listed non-cortical structures
aal_cortical = (idx <= 9000) & ~np.isin(labels, list(noncortical))

# Receptor files
receptor_files = {
    # Glutamate
    "dubois": datasets.fetch_annotation(source='dubois2015', return_single=True),
    "galovic": datasets.fetch_annotation(source='galovic2021', return_single=True),
    "rosaneto": datasets.fetch_annotation(source='rosaneto', return_single=True),
    "smart": datasets.fetch_annotation(source='smart2019', return_single=True),
    # Gaba
    "dukart": datasets.fetch_annotation(source='dukart2018', desc='flumazenil', return_single=True),
    "lukow": datasets.fetch_annotation(source='lukow2022', return_single=True),
    "norgaard": datasets.fetch_annotation(source='norgaard2021', space='MNI152', return_single=True),
    # Acetilcoline (control)
    "aghourian": datasets.fetch_annotation(source='aghourian2017', space='MNI152', return_single=True),
    "bedard": datasets.fetch_annotation(source='bedard2019', space='MNI152', return_single=True),
    "hillmer": datasets.fetch_annotation(source='hillmer2016', space='MNI152', return_single=True),
    "naganawa": datasets.fetch_annotation(source='naganawa2020', space='MNI152', return_single=True),
    "tuominen": datasets.fetch_annotation(source='tuominen', space='MNI152', return_single=True)
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

    # Apply mask (do not store non-cortical areas)
    arr = arr[aal_cortical]

    # Save individual receptor maps in a single .csv file
    outfile = os.path.join(outpath, ref + '.csv')
    np.savetxt(outfile, arr, delimiter=',')

    # Append to create a matrix of receptors
    receptor_data.append(arr)

receptor_data = np.column_stack(receptor_data)
reclabels = list(receptor_files.keys())

# Save full receptor matrix
savemat(os.path.join(outpath, 'rec_maps_aalspm8.mat'),{'receptors': receptor_data, 'labels': np.array(reclabels, dtype=object)})
np.savetxt(os.path.join(outpath, 'rec_maps_aalspm8.csv'),receptor_data,delimiter=',',header=','.join(reclabels), comments='')

# -----------------------------------------------------------------------------
# Perform a weighted average of receptors
# -----------------------------------------------------------------------------

# Weighted average of mGluR5
mGluR5 = (zscore(receptor_data[:, 0]) * 28 +
          zscore(receptor_data[:, 2]) * 22 +
          zscore(receptor_data[:, 3]) * 73) / (28 + 22 + 73)

# Weighted average of GABA_flumazenil
gaba_flumazenil = (zscore(receptor_data[:, 4]) * 6 +
                   zscore(receptor_data[:, 6]) * 16) / (6 + 16)

# Weighted average of VAChT
vacht = (zscore(receptor_data[:, 7]) * 18 +
         zscore(receptor_data[:, 8]) * 5 +
         zscore(receptor_data[:, 11]) * 4) / (18 + 5 + 4)

# Non-averaged receptors
nmda = receptor_data[:, 1]
gaba_a5 = receptor_data[:, 5]
ach_a4b2 = receptor_data[:, 9]
ach_m1 = receptor_data[:, 10]

# Concatenate into a matrix (columns)
matrix = np.column_stack((mGluR5, nmda, gaba_flumazenil, gaba_a5, vacht, ach_a4b2, ach_m1))
wa_labels = ['mGluR5', 'NMDA', 'GABA_flumazenil', 'GABA_a5', 'VAChT', 'ACh_a4b2', 'ACh_m1']

# Save weighted-average receptor matrix
savemat(os.path.join(outpath, 'rec_maps_wa_aalspm8.mat'),{'receptors_wa': matrix,'labels': np.array(wa_labels, dtype=object)})
np.savetxt(os.path.join(outpath, 'rec_maps_wa_aalspm8.csv'),matrix,delimiter=',', header=','.join(wa_labels), comments='')
