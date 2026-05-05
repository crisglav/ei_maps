# Correlate receptor maps parcellated to AAL with aperiodic exponentes computed in AAL rois
import os
import pandas as pd
from scipy.io import loadmat
from neuromaps import nulls, resampling, stats
from neuromaps.parcellate import Parcellater
import nibabel as nib
import numpy as np
from nilearn.datasets import fetch_atlas_aal
import warnings
warnings.simplefilter("ignore", FutureWarning)

# Load parcellated receptor data from .csv
receptors_path = os.path.join('../..', 'data', 'receptors', 'aal_spm8', 'rec_maps_wa_aalspm8.csv')
receptor_data = pd.read_csv(receptors_path)
receptor_names = receptor_data.columns.tolist()

# Load participants file
participants_path = os.path.join('../..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)
participant_info = participants.set_index("participant_id")[["session"]].to_dict("index")

# Load aperiodic exponents computed on AAL SPM8
project_root = r'C:\Users\Cristina\megtusalen'
apexp_files = {}

# Search files for each participant in the correct session folder
for pid, info in participant_info.items():
    session = info["session"]
    apexp_folder = os.path.join(project_root, session, 'data', 'sources', 'fooof')

    # Find files that belong to this participant
    participant_files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if (f.endswith("_rois.mat")) and f.split("_")[0] == pid
    ]

    apexp_files[pid] = participant_files[0] if participant_files else None

# AAL atlas
aal = fetch_atlas_aal(version='SPM8', data_dir=r'C:\Users\Cristina\nilearn_data')

# Remove non-nortical parcels
idx = np.array(aal['indices'], dtype=int)
labels = np.array(aal['labels'])
noncortical = {
    'Amygdala_L', 'Amygdala_R',
    'Caudate_L', 'Caudate_R',
    'Putamen_L', 'Putamen_R',
    'Pallidum_L', 'Pallidum_R',
    'Thalamus_L', 'Thalamus_R'
}
aal_cortical = (idx < 9000) & ~np.isin(labels, list(noncortical))
cortical_idx = idx[aal_cortical]

# Resample aal atlas to a low dimension grid that we used in sources. Otherwise it takes ages the creation of nulls.
ref_folder = os.path.join(project_root, 'L1', 'data', 'sources', 'apexp')
ref_files = [
    f for f in os.listdir(ref_folder)
    if f.endswith(".nii") or f.endswith(".nii.gz")
]
ref_file = os.path.join(ref_folder, ref_files[0])

aal_resampled, _ = resampling.resample_images(
        src=aal['maps'],
        trg=ref_file,
        src_space="MNI152",
        trg_space="MNI152",
        method="nearest",
        resampling='transform_to_trg'
    )

# zero all parcels not cortical
data = np.asanyarray(aal_resampled.dataobj).copy()
remove_ids = set(idx) - set(cortical_idx)
data[np.isin(data, list(remove_ids))] = 0

aal_resampled_cortical = nib.Nifti1Image(
    data.astype(np.int32),
    affine=aal_resampled.affine,
    header=aal_resampled.header
)

# ------------------------
# Correlations
# ------------------------

# Initialize dictionary
results = {pid: {"participant_id": pid} for pid in participants["participant_id"]}

# Loop over receptors
for receptor_name, receptor_values in receptor_data.items():

    # Nulls
    rotated = nulls.burt2020(receptor_values, atlas='mni152', density='3mm', parcellation=aal_resampled_cortical,
                             n_perm=10000, n_proc=12, seed=1234)

    # Loop over subjects/files
    for pid, apexp_file in apexp_files.items():

        print(f"Processing subject {pid} | receptor {receptor_name}")

        if apexp_file is None:
            results[pid][f"corr_{receptor_name}"] = np.nan
            results[pid][f"pval_{receptor_name}"] = np.nan
            continue

        try:
            # Extract apexp data in the brain mask
            apexp_mat = loadmat(apexp_file)
            apexp_data = apexp_mat['apexp_svd']

            # Compute correlation and pvalue
            corr, pval = stats.compare_images(receptor_values, apexp_data, nulls=rotated)

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
output_file = os.path.join('../..', 'results', f'corr_apexp_receptors_rois_svd.csv')

corr_df.to_csv(output_file, index=False)

print(f"Results saved to: {output_file}")