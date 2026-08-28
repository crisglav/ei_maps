# This scripts downloads neurotransmitter receptor maps via the neuromaps library, downsamples them to source grid,
# performs a weighted average of receptors of the same type
#
# Cristina Gil Ávila, C3N, 27/08/2026

import os
import json
import warnings
import numpy as np
import nibabel as nib
import scipy.io as sio
from scipy.stats import zscore
from neuromaps import datasets, resampling, images

warnings.simplefilter("ignore", FutureWarning)

# -----------------------
# Config
# -----------------------
config_file = os.path.join('..','config_megtusalen.json')
config = json.load(open(config_file))

# Project root
project_root = config['path']['project_root']

# Output folder
output_folder = os.path.join("..", "..", "data", "prepared_receptors")
os.makedirs(output_folder, exist_ok=True)

# Source grid, brain mask - ones at inside brain locations (2459)
sourcegrid_file = os.path.join('..', '..', 'data', 'templates', 'template.nii')
sourcegrid = nib.load(sourcegrid_file)
brain_mask = sourcegrid.get_fdata() != 0

# -----------------------
# Fetch receptors
# -----------------------
receptor_files = {
    # Glutamate
    "dubois": datasets.fetch_annotation(source="dubois2015", return_single=True),
    "galovic": datasets.fetch_annotation(source="galovic2021", return_single=True),
    "rosaneto": datasets.fetch_annotation(source="rosaneto", return_single=True),
    "smart": datasets.fetch_annotation(source="smart2019", return_single=True),

    # GABA
    "dukart": datasets.fetch_annotation(source="dukart2018", desc="flumazenil", return_single=True),
    "lukow": datasets.fetch_annotation(source="lukow2022", return_single=True),
    "norgaard": datasets.fetch_annotation(source="norgaard2021", space="MNI152", return_single=True),

    # Acetylcholine
    "hillmer": datasets.fetch_annotation(source="hillmer2016", space="MNI152", return_single=True),
    "naganawa": datasets.fetch_annotation(source="naganawa2020", space="MNI152", return_single=True),
}

# -----------------------
# Resample receptors
# -----------------------

resampled_receptors = {}

for receptor_name, receptor_file in receptor_files.items():
    print(f"Resampling receptor: {receptor_name}")

    receptor_resampled, _ = resampling.resample_images(
        src=receptor_file,
        trg=sourcegrid_file,
        src_space="MNI152",
        trg_space="MNI152",
        resampling="transform_to_trg",
    )

    resampled_receptors[receptor_name] = receptor_resampled

# -----------------------
# Weighted average
# -----------------------
weighted_groups = {
    "mGluR5": {"dubois": 28, "rosaneto": 22, "smart": 73},
    "NMDA": {"galovic": 29},
    "GABA_flumazenil": {"dukart": 6, "norgaard": 16},
    "GABA_a5": {"lukow": 10},
    "ACh_a4b2": {"hillmer": 30},
    "ACh_M1": {"naganawa": 24},
}

final_receptors = {}

for new_name, components in weighted_groups.items():
    print(f"Creating weighted receptor: {new_name}")

    weighted_sum = None
    total_weight = 0

    for receptor_name, weight in components.items():
        data = images.load_data(resampled_receptors[receptor_name]).astype(np.float64)

        # Zscore data inside brain
        zdata = np.zeros_like(data, dtype=np.float64)
        zdata[brain_mask] = zscore(
            data[brain_mask],
            axis=None,
            nan_policy="omit",
        )

        if weighted_sum is None:
            weighted_sum = np.zeros_like(zdata, dtype=np.float64)

        weighted_sum += weight * zdata
        total_weight += weight

    avg_data = weighted_sum / total_weight

    ref_img = resampled_receptors[next(iter(components))]
    final_receptors[new_name] = nib.Nifti1Image(
        avg_data,
        ref_img.affine,
        ref_img.header,
    )


# -----------------------
# Save receptors
# -----------------------

for receptor_name, receptor_img in final_receptors.items():
    out_path = os.path.join(output_folder, f"{receptor_name}.nii.gz")
    nib.save(receptor_img, out_path)
    print(f"Saved: {out_path}")

print(f"Prepared receptors saved to: {output_folder}")