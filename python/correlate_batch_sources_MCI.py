import os
import warnings
import numpy as np
import pandas as pd
from scipy.stats import zscore
import nibabel as nib
from neuromaps import datasets, resampling, stats, images, nulls

warnings.simplefilter("ignore", FutureWarning)

# -----------------------
# Config
# -----------------------

# Number of permutations for the statistical test
n_perm = 1000

# Variable to perform a weighted average of the receptors
config_weighted = True

# Path to project root
project_root = r'C:\Users\Cristina\megtusalen'

# Results path
results_folder = os.path.join('..', "results")
os.makedirs(results_folder, exist_ok=True)
output_file = os.path.join(results_folder, f"MCI_corr_apexp_receptors_wa.csv")

# -----------------------
# Aperiodic exponents
# -----------------------
# Load participants file
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# NEMOS ONLY
participants = participants[participants["participant_id"].astype(str).str.startswith("NEMOS")]

group = ['MCIneg', 'MCIa', 'MCIm', 'CONV']
subset = participants[participants["group"].isin(group)]

participant_info = subset.set_index("participant_id")[["session"]].to_dict("index")

apexp_files = {}

# Search files for each participant in the correct session folder
for pid, info in participant_info.items():

    apexp_folder = os.path.join(project_root, 'L1', 'data', 'sources', 'apexp')

    # Find files that belong to this participant
    participant_files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if (f.endswith(".nii") or f.endswith(".nii.gz")) and f.split("_")[0] == pid
    ]

    apexp_files[pid] = participant_files[0] if participant_files else None


# ------------------------
# Receptor maps
# ------------------------
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

# Brain mask for testing statistical significance
# Note that we use a brain mask in form of a parcellation file, with each location inside the brain given a different number
# Parcellation variants
parcellation_data = nib.load(os.path.join('..', 'data', 'parcellation_cortical.nii'))

# Get binary mask from all the values in parcellation_data that are non-zero
brain_mask = parcellation_data.get_fdata() != 0
brain_mask_flat = brain_mask.flatten()

# Resample receptor map to the smaller resolution grid used for computing apexp. Use an arbitrary apexp file
ref_folder = os.path.join(project_root, 'L1', 'data', 'sources', 'apexp')
ref_files = [
    f for f in os.listdir(ref_folder)
    if f.endswith(".nii") or f.endswith(".nii.gz")
]
ref_file = os.path.join(ref_folder, ref_files[0])

# Resample each receptor only once
resampled_receptors = {}
for receptor_name, receptor_file in receptor_files.items():
    receptor_resampled, _ = resampling.resample_images(
        src=receptor_file,
        trg=ref_file,
        src_space="MNI152",
        trg_space="MNI152",
        resampling="transform_to_trg"
    )
    resampled_receptors[receptor_name] = receptor_resampled

# Perform a weighted average of receptors of the same type or rename maps
weighted_groups = {
    "mGluR5": {"dubois": 28, "rosaneto": 22, "smart": 73},
    "NMDA": {"galovic":29},
    "GABA_flumazenil":{"dukart":6, "norgaard":16},
    "GABA_a5":{"lukow":10},
    "VAChT": {"aghourian": 18, "bedard": 5, "tuominen": 4},
    "ACh_a4b2": {"hillmer": 30},
    "ACh_M1": {"naganawa": 24}
}

weighted_receptors = {}
for new_name, components in weighted_groups.items():
    weighted_sum = None
    total_weight = 0

    for receptor_name, weight in components.items():
        data = images.load_data(resampled_receptors[receptor_name]).astype(np.float64)

        # --- Z-SCORE WITHIN BRAIN MASK ---
        zdata = np.zeros_like(data, dtype=np.float64)
        zdata[brain_mask] = zscore(data[brain_mask], axis=None, nan_policy='omit')

        if weighted_sum is None:
            weighted_sum = np.zeros_like(zdata, dtype=np.float64)

        weighted_sum += weight * zdata
        total_weight += weight

    avg_data = weighted_sum / total_weight
    ref_img = resampled_receptors[next(iter(components))]
    weighted_receptors[new_name] = nib.Nifti1Image(avg_data, ref_img.affine, ref_img.header)

resampled_receptors = weighted_receptors


# ------------------------
# Correlations
# ------------------------

# Initialize dictionary
results = {pid: {"participant_id": pid} for pid in subset["participant_id"]}

# Loop over receptors
for receptor_name, receptor_img in resampled_receptors.items():
    # Extract receptor data in the brain mask
    receptor_data = images.load_data(receptor_img).flatten()[brain_mask_flat]

    # Compute the spatial nulls
    rotated = nulls.burt2020(receptor_data, atlas='mni152', density='2mm', parcellation=parcellation_data,
                             n_perm=n_perm, n_proc=12, seed=1234)

    # Embed spatial nulls into the 3D grid of parcellation
    nulls_4d = np.zeros(brain_mask.shape + (n_perm,), dtype=rotated.dtype)
    nulls_4d.reshape(-1, n_perm)[brain_mask_flat, :] = rotated

    # Loop over subjects/files
    for pid, apexp_file in apexp_files.items():

        print(f"Processing subject {pid} | receptor {receptor_name}")

        if apexp_file is None:
            results[pid][f"corr_{receptor_name}"] = np.nan
            results[pid][f"pval_{receptor_name}"] = np.nan
            continue

        try:
            # Extract apexp data in the brain mask
            apexp_data = images.load_data(apexp_file)

            # --- Z-SCORE WITHIN BRAIN MASK ---
            if config_weighted:
                apexp_aux = np.zeros_like(apexp_data, dtype=np.float64)
                apexp_aux[brain_mask] = zscore(apexp_data[brain_mask], axis=None, nan_policy='omit')
                apexp_data = apexp_aux

            # Compute correlation and pvalue
            corr, pval = stats.compare_images(receptor_img, apexp_data, nulls=nulls_4d)

            # Fill results dictionary
            results[pid][f"corr_{receptor_name}"] = corr
            results[pid][f"pval_{receptor_name}"] = pval

        except Exception as e:
            print(f"Error processing {pid} with {receptor_name}: {e}")
            results[pid][f"corr_{receptor_name}"] = np.nan
            results[pid][f"pval_{receptor_name}"] = np.nan

# Convert results to dataframe
corr_df = pd.DataFrame(results.values())

# Save dataframe
corr_df.to_csv(output_file, index=False)

print(f"Results saved to: {output_file}")