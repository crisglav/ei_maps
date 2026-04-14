import os
import numpy as np
import pandas as pd
import nibabel as nib
from neuromaps import datasets, resampling, stats, images, nulls
from nilearn.image import mean_img, smooth_img

# Path to project root
project_root = r'C:\Users\Cristina\megtusalen'

# Path to results csv
results_file = os.path.join('..', 'results', 'corr_apexp_receptors_hc.csv')

# Load participants file
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Filter healthy participants
groups = ['FHpos', 'FHneg', 'SCDneg', 'MCIneg']
healthy = participants[participants['group'].isin(groups)]

# Receptor maps
receptor_files = {
    "dubois": datasets.fetch_annotation(source='dubois2015', return_single=True),
    "galovic": datasets.fetch_annotation(source='galovic2021', return_single=True),
    "rosaneto": datasets.fetch_annotation(source='rosaneto', return_single=True),
    "smart": datasets.fetch_annotation(source='smart2019', return_single=True),
    "dukart": datasets.fetch_annotation(source='dukart2018', desc='flumazenil', return_single=True),
    "lukow": datasets.fetch_annotation(source='lukow2022', return_single=True),
    "norgaard": datasets.fetch_annotation(source='norgaard2021', space='MNI152', return_single=True),
}

# Brain mask for testing statistical significance
# Note that we use a brain mask in form of a parcellation file, with each location inside the brain given a different number
parcellation_file = os.path.join('..', 'data', 'parcellation.nii')
parcellation_data = nib.load(parcellation_file)

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

# List all the files in the apexp folder
apexp_folder = os.path.join(project_root, 'L1', 'data', 'sources', 'apexp')

# List ids
ids = healthy['participant_id'].astype(str)

# Keep only files from healthy participants
apexp_files = [
    f for f in os.listdir(apexp_folder)
    if (f.endswith(".nii") or f.endswith(".nii.gz"))
       and any(f.startswith(pid) for pid in ids)
]

# Number of permutations for the statistical test
n_perm = 1000

# Store one row per participant_id
results = {}

# Initialize dictionary with all participants
for subject_file in apexp_files:
    participant_id = subject_file.split("_")[0]
    results[participant_id] = {"participant_id": participant_id}

# Loop over receptors
for receptor_name, receptor_img in resampled_receptors.items():

    # Extract receptor data in the brain mask
    receptor_data = images.load_data(receptor_img)
    receptor_data_flat = receptor_data.flatten()
    receptor_data_flat = receptor_data_flat[brain_mask_flat]

    # Compute the spatial nulls
    rotated = nulls.burt2020(receptor_data_flat, atlas='mni152', density='2mm', parcellation=parcellation_data,
                             n_perm=n_perm, n_proc=12, seed=1234)

    # Embed spatial nulls into the 3D grid of parcellation
    nulls_4d = np.zeros(brain_mask.shape + (n_perm,), dtype=rotated.dtype)
    nulls_4d.reshape(-1, n_perm)[brain_mask_flat, :] = rotated


    # Loop over subjects/files
    for subject_file in apexp_files:
        apexp_file = os.path.join(apexp_folder, subject_file)
        participant_id = subject_file.split("_")[0]

        try:
            # Extract apexp data in the brain mask
            apexp_data = images.load_data(apexp_file)

            # Compute correlation and pvalue
            corr, pval = stats.compare_images(receptor_img, apexp_data, nulls=nulls_4d)

            # Fill results dictionary
            results[participant_id][f"corr_{receptor_name}"] = corr
            results[participant_id][f"pval_{receptor_name}"] = pval

        except Exception as e:
            print(f"Error processing {subject_file} with {receptor_name}: {e}")
            results_dict[participant_id][f"corr_{receptor_name}"] = np.nan
            results_dict[participant_id][f"pval_{receptor_name}"] = np.nan

# Convert results to dataframe
corr_df = pd.DataFrame(results.values())

# Merge back into healthy dataframe
healthy = healthy.merge(corr_df, on="participant_id",how="left")

# Create results folder
results_folder = os.path.join('..', "results")
os.makedirs(results_folder, exist_ok=True)

# Save dataframe
output_file = os.path.join(results_folder, "corr_apexp_receptors_HC_smoothed.csv")
healthy.to_csv(output_file, index=False)

print(f"Results saved to: {output_file}")


