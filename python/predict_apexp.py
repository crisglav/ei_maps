import os

import nibabel as nib
import numpy as np
import pandas as pd
from scipy.stats import zscore
from neuromaps import stats, images, nulls
from sklearn.linear_model import LinearRegression
from netneurotools import stats
import matplotlib.pyplot as plt
from sklearn.preprocessing import PolynomialFeatures
import scipy.io
# Paths
project_path = r"C:\Users\Cristina\megtusalen"
data_path = os.path.join("..", "data")

participants_path = os.path.join(data_path, "participants_real.xlsx")
receptors_path = os.path.join(data_path, "prepared_receptors")
parcellation_file = os.path.join('..', 'data', 'parcellation_cortical.nii')

# -----------------------
# Brain mask
# -----------------------
parcellation_img = nib.load(parcellation_file)
brain_mask = parcellation_img.get_fdata() != 0
brain_mask_flat = brain_mask.flatten()

# -----------------------
# Load receptors
# -----------------------

receptor_data = {}

for fname in os.listdir(receptors_path):
    if fname.endswith(".nii") or fname.endswith(".nii.gz"):
        name = fname.replace(".nii.gz", "").replace(".nii", "")
        path = os.path.join(receptors_path, fname)

        img = nib.load(path)
        img_data = images.load_data(img)
        img_data = img_data.flatten()[brain_mask_flat]
        receptor_data[name] = img_data


# -----------------------
# Load participant metadata
# -----------------------
participants = pd.read_excel(participants_path)

# Only healthy participants from the FAM project
participants = participants[
    participants["participant_id"]
    .astype(str)
    .str
    .startswith("FAM")
].copy()

# Exclude participants due to a poor fitting of the model
exclude_ids = ["FAM-054", "FAM-125", "FAM-197"]
participants = participants[
    ~participants["participant_id"].isin(exclude_ids)
].copy()

participant_info = (
    participants
    .set_index("participant_id")[["session"]]
    .to_dict("index")
)

# -----------------------
# List files containing individual aperiodic exponents
# -----------------------

apexp_data = {}
for pid, info in participant_info.items():
    session = info["session"]

    apexp_folder = os.path.join(
        project_path,
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

    img = nib.load(files[0])
    img_data = images.load_data(img)
    img_data = img_data.flatten()[brain_mask_flat]
    # apexp_data[pid] = zscore(img_data,nan_policy="omit")
    apexp_data[pid] = img_data


# ------------------------
# Multiple linear regression
# ------------------------
receptor_names = ['mGluR5','NMDA','GABA_flumazenil','GABA_a5','ACh_a4b2','ACh_M1']

x = np.column_stack([
    receptor_data[name] for name in receptor_names
])
n_predictor = x.shape[1]

results = []

for pid, y in apexp_data.items():

    valid = ~np.isnan(y)
    x_valid = x[valid]
    y_valid = y[valid]

    if len(y_valid) == 0:
        print(f"Skipping {pid}: no valid data")
        continue

    reg = LinearRegression()
    reg.fit(x_valid, y_valid)
    coef = reg.coef_
    rsquared = reg.score(x_valid, y_valid)

    row = {
        "participant_id": pid,
        "rsquared": rsquared
    }

    # Add coefficients with receptor names
    for i, receptor in enumerate(receptor_names):
        row[f"coef_{receptor}"] = coef[i]

    results.append(row)

# Convert to dataframe
results_df = pd.DataFrame(results)

# ------------------------
# Multiple linear regression with interactions
# ------------------------
# Create interaction terms
# poly = PolynomialFeatures(
#     degree=2,
#     interaction_only=True,
#     include_bias=False
# )
#
# x_full = poly.fit_transform(x)
#
# predictor_names = poly.get_feature_names_out(receptor_names)
#
# results = []
#
# for pid, y in apexp_data.items():
#
#
#     valid = ~np.isnan(y)
#     x_valid = x_full[valid]
#     y_valid = y[valid]
#
#     if len(y_valid) == 0:
#         print(f"Skipping {pid}: no valid data")
#         continue
#
#     reg = LinearRegression()
#     reg.fit(x_valid, y_valid)
#     coef = reg.coef_
#     rsquared = reg.score(x_valid, y_valid)
#
#     row = {
#         "participant_id": pid,
#         "rsquared": rsquared
#     }
#
#     # Add coefficients with receptor names
#     for i, name in enumerate(predictor_names):
#         row[f"coef_{name}"] = coef[i]
#
#     results.append(row)

# Convert to dataframe
# results_df = pd.DataFrame(results)
# Select coefficient columns
coef_cols = [col for col in results_df.columns if col.startswith("coef_")]

# Compute mean and std
summary_df = pd.DataFrame({
    "median": results_df[coef_cols].median(),
    "std": results_df[coef_cols].std()
})

# Clean index names
summary_df.index = summary_df.index.str.replace("coef_", "", regex=False)

# Print all rows
pd.set_option("display.max_rows", None)
pd.set_option("display.max_columns", None)

print(summary_df)

# Plot rsquared
plt.figure(figsize=(3, 5))

x_r2 = np.random.normal(
    loc=1,
    scale=0.05,
    size=len(results_df),
)

y_r2 = results_df["rsquared"]


# Good R² points
plt.scatter(
    x_r2,
    y_r2,
    color="gray",
    alpha=0.7,
)

# Mean line
mean_r2 = np.nanmean(y_r2)

plt.plot(
    [0.8, 1.2],
    [mean_r2, mean_r2],
    color="black",
    linewidth=2,
)

# Formatting
plt.xticks([1], ["R²"])

ax = plt.gca()
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

plt.ylabel("Explained variance")

plt.axhline(
    0,
    color="black",
    linewidth=1,
    linestyle="--",
)

plt.tight_layout()
plt.show()


# ------------------------
# Dominance analysis
# ------------------------
dominance = []
for pid, y in apexp_data.items():

    valid = ~np.isnan(y)
    x_valid = x[valid]
    y_valid = y[valid]

    m, _ = stats.get_dominance_stats(x_valid,y_valid, verbose=True, n_jobs=4)
    row = {
        "participant_id": pid,
        "rsquared": m['full_r_sq']
    }

    # Add coefficients with receptor names
    for i, receptor in enumerate(receptor_names):
        row[f"dom_{receptor}"] = m['total_dominance'][i]

    dominance.append(row)

dominance_df = pd.DataFrame(dominance)

# ------------------------
# Plotting
# ------------------------
RECEPTOR_COLORS = {
    # Glutamate
    "mGluR5": "#f9a825",
    "NMDA": "#f9a825",

    # GABA
    "GABA_flumazenil": "#1565c0",
    "GABA_a5": "#1565c0",

    # Acetylcholine
    "ACh_a4b2": "#F06292",
    "ACh_M1": "#F06292",
}
r2_threshold = 0.2

plt.figure(figsize=(10, 5))

for i, receptor in enumerate(receptor_names):

    coef_col = f"dom_{receptor}"

    # Jittered x positions
    x = np.random.normal(
        loc=i + 1,
        scale=0.05,
        size=len(dominance_df),
    )

    y = dominance_df[coef_col]

    # good_fit = results_df["rsquared"] >= r2_threshold
    # bad_fit = results_df["rsquared"] < r2_threshold

    # Plot coefficients
    plt.scatter(
        x,
        y,
        color=RECEPTOR_COLORS.get(receptor, "black"),
        alpha=0.7,
    )

    # plt.scatter(
    #     x[good_fit],
    #     y[good_fit],
    #     color=RECEPTOR_COLORS.get(receptor, "black"),
    #     alpha=0.7,
    # )
    # Poor fit points in grey
    # plt.scatter(
    #     x[bad_fit],
    #     y[bad_fit],
    #     color="lightgray",
    #     alpha=0.7,
    # )

    mean_y = np.nanmean(y)

    plt.plot(
        [i + 0.8, i + 1.2],
        [mean_y, mean_y],
        color="black",
        linewidth=2,
    )

# Axis formatting
plt.xticks(
    ticks=range(1, len(receptor_names) + 1),
    labels=receptor_names,
    rotation=45,
)

# Remove top and right borders
ax = plt.gca()
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

plt.ylabel("Dominance")

plt.axhline(
    0,
    color="black",
    linewidth=1,
    linestyle="--",
)

plt.tight_layout()
plt.show()
