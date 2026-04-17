# Correlate receptor maps parcellated to AAL with aperiodic exponentes computed in AAL rois
import os
import pandas as pd
from scipy.io import loadmat


# Figures folder
figs_folder = os.path.join('..', 'figs', 'brainmaps','schaefer')
os.makedirs(figs_folder, exist_ok=True)

# Load parcellated data from .csv
receptors_path = os.path.join('..', 'data', 'receptors', 'aal_spm8', 'rec_maps_aalspm8.csv')
receptor_data = pd.read_csv(receptors_path)
receptor_names = receptor_data.columns.tolist()

# Load aperiodic exponents computed on AAL SPM8
# fooof_path =
data = loadmat('rec_maps_aalspm8.mat')

# Load participants file
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Sessions to analyze
sessions = ["L1", "L2"]

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