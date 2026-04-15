import os
import numpy as np
import pandas as pd
import nibabel as nib

from nilearn.datasets import fetch_atlas_schaefer_2018
from neuromaps.parcellate import Parcellater
from neuromaps import datasets, resampling, stats, images, nulls
from scipy.io import savemat

schaefer = fetch_atlas_schaefer_2018(n_rois=200)

outpath = os.path.join('..', 'data', 'receptors', 'schaefer200')
os.makedirs(outpath, exist_ok=True)


# Path to project root
project_root = r'C:\Users\Cristina\megtusalen'

# Load participants file
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Sessions to analyze
sessions = ["L1", "L2"]

# List to store parcellated apexp
parcellated = {}
neuromaps_rec = []
parcellater = Parcellater(schaefer['maps'], 'MNI152')


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

        # Parcellate apexp file


        # Start one result row per subject/session
        row = {
            "participant_id": participant_id,
            "session": session,
        }

        try:
            # Compute correlation for each receptor
            for receptor_name, receptor_img in resampled_receptors.items():
                corr = stats.compare_images(receptor_img, apexp_file)
                row[f"corr_{receptor_name}"] = corr

            results.append(row)

            print(
                f"{session} | {subject_file} | " +
                " | ".join(
                    [f"corr_{r} = {row[f'corr_{r}']:.4f}" for r in resampled_receptors]
                )
            )

        except Exception as e:
            print(f"Error processing {session} | {subject_file}: {e}")

# Convert results to dataframe
corr_df = pd.DataFrame(results)

# Merge back into participants dataframe
participants = participants.merge(
    corr_df,
    on=["participant_id", "session"],
    how="left"
)

# Create results folder
results_folder = os.path.join('..', "results")
os.makedirs(results_folder, exist_ok=True)

# Save dataframe
output_file = os.path.join(results_folder, "corr_apexp_receptors.csv")
participants.to_csv(output_file, index=False)

print(f"Results saved to: {output_file}")