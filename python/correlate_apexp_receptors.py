import os
import warnings

import nibabel as nib
import numpy as np
import pandas as pd
from scipy.stats import zscore
from neuromaps import stats, images, nulls

warnings.simplefilter("ignore", FutureWarning)

# -----------------------
# Config
# -----------------------

N_PERM = 1000
N_PROC = 12
SEED = 1234

CONFIG_WEIGHTED = True

FILTER_FAM = True

PROJECT_ROOT = r"C:\Users\Cristina\megtusalen"

DATA_FOLDER = os.path.join("..", "data")
RESULTS_FOLDER = os.path.join("..", "results")

os.makedirs(RESULTS_FOLDER, exist_ok=True)

# Output file
suffix = "wa_" if CONFIG_WEIGHTED else ""
fam_suffix = "FAM_" if FILTER_FAM else ""

output_file = os.path.join(
    RESULTS_FOLDER,
    f"corr_apexp_receptors_{suffix}{fam_suffix}PYTHONINFPEAKS_NEWSCRIPT.csv"
)

# Paths
participants_path = os.path.join(DATA_FOLDER, "participants_real.xlsx")
receptors_folder = os.path.join(DATA_FOLDER, f"prepared_receptors")

parcellation_file = os.path.join('..', 'data', 'parcellation.nii')

# -----------------------
# Load participants metadata
# -----------------------

participants = pd.read_excel(participants_path)

if FILTER_FAM:
    participants = participants[
        participants["participant_id"]
        .astype(str)
        .str
        .startswith("FAM")
    ].copy()

    print(f"Filtering: keeping {len(participants)} FAM participants")
else:
    print(f"Using all participants: {len(participants)}")

participant_info = (
    participants
    .set_index("participant_id")[["session"]]
    .to_dict("index")
)

# -----------------------
# Locate apexp files
# -----------------------

apexp_files = {}

for pid, info in participant_info.items():
    session = info["session"]

    apexp_folder = os.path.join(
        PROJECT_ROOT,
        session,
        "data",
        "sources",
        "fooof_py_infpeaks",
    )

    if not os.path.exists(apexp_folder):
        apexp_files[pid] = None
        continue

    files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if (f.endswith(".nii") or f.endswith(".nii.gz"))
        and f.split("_")[0] == pid
    ]

    apexp_files[pid] = files[0] if files else None


# -----------------------
# Load receptors
# -----------------------

resampled_receptors = {}

if not os.path.exists(receptors_folder):
    raise FileNotFoundError(f"Receptors folder not found: {receptors_folder}")

for fname in os.listdir(receptors_folder):
    if fname.endswith(".nii") or fname.endswith(".nii.gz"):
        name = fname.replace(".nii.gz", "").replace(".nii", "")
        path = os.path.join(receptors_folder, fname)
        resampled_receptors[name] = nib.load(path)

if not resampled_receptors:
    raise RuntimeError("No receptor maps found.")

print(f"Loaded {len(resampled_receptors)} receptors")


# -----------------------
# Brain mask
# -----------------------
parcellation_img = nib.load(parcellation_file)

brain_mask = parcellation_img.get_fdata() != 0
brain_mask_flat = brain_mask.flatten()


# ------------------------
# Correlations
# ------------------------

results = {
    pid: {"participant_id": pid}
    for pid in participants["participant_id"]
}

for receptor_name, receptor_img in resampled_receptors.items():

    # Extract receptor data in the brain mask
    receptor_data = images.load_data(receptor_img)
    receptor_data = receptor_data.flatten()[brain_mask_flat]

    # Spatial nulls
    print(f"\nComputing nulls for receptor: {receptor_name}")

    nulls_flat = nulls.burt2020(
        receptor_data,
        atlas="mni152",
        density="2mm",
        parcellation=parcellation_img,
        n_perm=N_PERM,
        n_proc=N_PROC,
        seed=SEED,
    )

    # Embed spatial nulls into the 3D grid
    nulls_4d = np.zeros(
        brain_mask.shape + (N_PERM,),
        dtype=nulls_flat.dtype
    )
    nulls_4d.reshape(-1, N_PERM)[brain_mask_flat, :] = nulls_flat

    # Loop over subjects
    for pid, apexp_file in apexp_files.items():

        print(f"Processing subject {pid} | receptor {receptor_name}")

        corr_key = f"corr_{receptor_name}"
        pval_key = f"pval_{receptor_name}"

        if apexp_file is None:
            results[pid][corr_key] = np.nan
            results[pid][pval_key] = np.nan
            continue

        try:
            # Extract apexp data in the brain mask
            apexp_data = images.load_data(apexp_file)

            # Z-score inside mask
            if CONFIG_WEIGHTED:
                zdata = np.zeros_like(apexp_data, dtype=np.float64)
                zdata[brain_mask] = zscore(
                    apexp_data[brain_mask],
                    axis=None,
                    nan_policy="omit",
                )
                apexp_data = zdata


            # Correlation
            corr, pval = stats.compare_images(
                receptor_img,
                apexp_data,
                nulls=nulls_4d,
            )

            results[pid][corr_key] = corr
            results[pid][pval_key] = pval

        except Exception as e:
            print(f"Error: {pid} | {receptor_name} -> {e}")
            results[pid][corr_key] = np.nan
            results[pid][pval_key] = np.nan

# -----------------------
# Save results
# -----------------------

corr_df = pd.DataFrame(results.values())
corr_df.to_csv(output_file, index=False)

print(f"\nResults saved to: {output_file}")