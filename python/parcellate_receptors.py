import os
import numpy as np
from nilearn.datasets import fetch_atlas_schaefer_2018
from neuromaps.parcellate import Parcellater
from neuromaps import datasets
from scipy.io import savemat

schaefer = fetch_atlas_schaefer_2018(n_rois=200)

outpath = os.path.join('..', 'data', 'receptors', 'schaefer200')
os.makedirs(outpath, exist_ok=True)

receptor_files = {
    "dubois": datasets.fetch_annotation(source='dubois2015', return_single=True),
    "galovic": datasets.fetch_annotation(source='galovic2021', return_single=True),
    "rosaneto": datasets.fetch_annotation(source='rosaneto', return_single=True),
    "smart": datasets.fetch_annotation(source='smart2019', return_single=True),
    "dukart": datasets.fetch_annotation(source='dukart2018', desc='flumazenil', return_single=True),
    "lukow": datasets.fetch_annotation(source='lukow2022', return_single=True),
    "norgaard": datasets.fetch_annotation(source='norgaard2021', space='MNI152', return_single=True),
}

# prepare maps
parcellated = {}
neuromaps_rec = []
parcellater = Parcellater(schaefer['maps'], 'MNI152')
for ref, receptor in receptor_files.items():
    parcellated = parcellater.fit_transform(receptor, 'MNI152', True)
    outfile = os.path.join(outpath, ref + '.csv')
    np.savetxt(outfile, parcellated, delimiter=',')
    neuromaps_rec.append( np.asarray(parcellated).squeeze())


neuromaps_receptors= np.array(neuromaps_rec).T
reclabels = list(receptor_files.keys())

savemat(os.path.join(outpath, 'rec_maps_schaefer200.mat'), {'neuromaps_receptors': neuromaps_receptors, 'reclabels': np.array(reclabels, dtype=object)})