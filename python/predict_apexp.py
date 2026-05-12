import os

# import nibabel as nib
# import numpy as np
# import pandas as pd
# from scipy.stats import zscore
# from neuromaps import stats, images, nulls


# -----------------------
# Config
# -----------------------

# N_PERM = 1000
# N_PROC = 12
# SEED = 1234
#
# CONFIG_WEIGHTED = True
#
# FILTER_FAM = True
#


# RESULTS_FOLDER = os.path.join("..", "results")
#
# os.makedirs(RESULTS_FOLDER, exist_ok=True)
#
# # Output file
# suffix = "wa_" if CONFIG_WEIGHTED else ""
# fam_suffix = "FAM_" if FILTER_FAM else ""
#
# output_file = os.path.join(
#     RESULTS_FOLDER,
#     f"corr_apexp_receptors_{suffix}{fam_suffix}PYTHONINFPEAKS_NEWSCRIPT.csv"
# )
#
# # Paths
PROJECT_ROOT = r"C:\Users\Cristina\megtusalen"

DATA_FOLDER = os.path.join("..", "data")
participants_path = os.path.join(DATA_FOLDER, "participants_real.xlsx")
receptors_folder = os.path.join(DATA_FOLDER, f"prepared_receptors")



# -----------------------
# Load receptors
# -----------------------

resampled_receptors = {}

for fname in os.listdir(receptors_folder):
    if fname.endswith(".nii") or fname.endswith(".nii.gz"):
        name = fname.replace(".nii.gz", "").replace(".nii", "")
        path = os.path.join(receptors_folder, fname)
        resampled_receptors[name] = nib.load(path)

print(f"Loaded {len(resampled_receptors)} receptors")

# -----------------------
# Load participant metadata
# -----------------------
participants = pd.read_excel(participants_path)
participant_info = (
    participants
    .set_index("participant_id")[["session"]]
    .to_dict("index")
)

# -----------------------
# List files containing individual aperiodic exponents
# -----------------------

apexp_files = {}

for pid, info in participant_info.items():
    session = info["session"]

    apexp_folder = os.path.join(
        PROJECT_ROOT,
        session,
        "data",
        "sources",
        "fooof_py",
    )

    files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if (f.endswith(".nii") or f.endswith(".nii.gz"))
        and f.split("_")[0] == pid
    ]

    apexp_files[pid] = files[0] if files else None

# ------------------------
# Multiple linear regression
# ------------------------