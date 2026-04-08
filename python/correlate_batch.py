import os
import numpy as np
import pandas as pd
import nibabel as nib
from neuromaps import datasets, resampling, stats, images, nulls

# Path to project root
project_root = r'C:\Users\Cristina\megtusalen'

# Load participants file
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Sessions to analyze
sessions = ["L1", "L2"]

# Path to receptor map
dubois_file = datasets.fetch_annotation(source='dubois2015', return_single=True)

# Resample receptor map to the smaller resolution grid used for computing apexp. Use an arbitrary apexp file
ref_folder = os.path.join(project_root, sessions[0], "data", "sources", "apexp")
ref_files = [
    f for f in os.listdir(ref_folder)
    if f.endswith(".nii") or f.endswith(".nii.gz")
]
ref_file = os.path.join(ref_folder, ref_files[0])

dubois_resampled, _ = resampling.resample_images(
    src=dubois_file,
    trg=ref_file,
    src_space="MNI152",
    trg_space="MNI152",
    resampling="transform_to_trg"
)

# List to store results
results = []

# Loop over sessions
for session in sessions:

    # List all the files in the apexp folder
    apexp_folder = os.path.join(project_root, session, "data", "sources", "apexp")

    # Get valid IDs for this session
    session_ids = set(
        participants.loc[participants['session'] == session, 'participant_id']
        .astype(str)
    )

    # Keep only files that are included in participants excel for this session
    apexp_files = [
        f for f in os.listdir(apexp_folder)
        if (f.endswith(".nii") or f.endswith(".nii.gz"))
           and any(f.startswith(pid) for pid in session_ids)
    ]

    # Loop over subjects/files
    for subject_file in apexp_files:
        apexp_file = os.path.join(apexp_folder, subject_file)
        participant_id = subject_file.split("_")[0]

        try:
            # Correlation
            corr = stats.compare_images(dubois_resampled, apexp_file)

            # Store result
            results.append({
                "participant_id": participant_id,
                "session": session,
                "corr_dubois": corr
            })

            print(f"{session} | {subject_file} | r = {corr:.4f}")

        except Exception as e:
            print(f"Error processing {session} | {subject_file}: {e}")

# Merge back into participants dataframe
corr_df = pd.DataFrame(results)

participants = participants.merge(
    corr_df,
    on=["participant_id", "session"],
    how="left"
)

# Create results folder
results_folder = os.path.join('..', "results")
os.makedirs(results_folder, exist_ok=True)

# Define output path
output_file = os.path.join(results_folder, "corr_apexp_receptors.csv")

# Save dataframe
participants.to_csv(output_file, index=False)

print(f"Results saved to: {output_file}")


# # %% Test for statistical significance of the correlation
# # Path to parcellation (brain mask)
# # Note that we use a fake parcellation with as many regions as source locations inside the brain to decrease the computation of null models
# parcellation_file = os.path.join('..','data','parcellation.nii')
# parcellation_data = nib.load(parcellation_file)
#
# # Get binary mask from all the values in parcellation_data that are non-zero
# brain_mask = parcellation_data.get_fdata() != 0
# brain_mask_flat = brain_mask.flatten()
#
# # Extract dubois data in the brain mask
# dubois_data = images.load_data(dubois)
# dubois_data_flat = dubois_data.flatten()
# dubois_data_flat = dubois_data_flat[brain_mask_flat]
#
# # Extract apexp data in the brain mask
# apexp_data = images.load_data(apexp)
# apexp_data_flat = apexp_data.flatten()
# apexp_data_flat = apexp_data_flat[brain_mask_flat]
# #%%
# # Compute the spatial nulls
# n_perm = 1000
# rotated = nulls.burt2020(dubois_data_flat, atlas = 'mni152', density = '2mm', parcellation=parcellation_data, n_perm=n_perm, n_proc=12, seed=1234)
# #%%
# # Embed spatial nulls into the original 3d grid
# nulls_4d = np.zeros(brain_mask.shape + (n_perm,), dtype=rotated.dtype)
# nulls_4d.reshape(-1, n_perm)[brain_mask_flat, :] = rotated
# #%%
# # Compute correlation with pvalue
# corr, pval = stats.compare_images(dubois, apexp, nulls=nulls_4d)
# print(f'Correlation: r = {corr:.04f}, p = {pval:.04f}')