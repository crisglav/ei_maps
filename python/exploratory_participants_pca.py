import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from scipy.stats import zscore
from sklearn.decomposition import PCA

np.random.seed(42)

# -----------------
# Load and select participants
# -----------------

participants_path = r"C:\Users\Cristina\megtusalen\L1\data\participants\participants_megtusalen_corrected_diagcog.xlsx"
participants = pd.read_excel(participants_path)

participants_ei_path = r"C:\Users\Cristina\repos\ei_maps\data\participants_sample_new.xlsx"
participants_ei = pd.read_excel(participants_ei_path)

participants = participants.merge(
    participants_ei[["participant_id", "included"]],
    on="participant_id",
    how="left"
)

participants = participants[participants["included"] == True].copy()

# -----------------
# Harmonize education level
# -----------------

# education_labels = {
#     1: "Low education",
#     2: "Basic/Primary education",
#     3: "Secondary education or Bachelor",
#     4: "Higher education/University"
# }

participants["edu_level"] = np.nan

mask = participants["project_id"] == "UMEC"

participants.loc[mask & participants["edu_level_umec"].isin([1]), "edu_level"] = 1
participants.loc[mask & participants["edu_level_umec"].isin([2, 3]), "edu_level"] = 2
participants.loc[mask & participants["edu_level_umec"].isin([4]), "edu_level"] = 3
participants.loc[mask & participants["edu_level_umec"].isin([5]), "edu_level"] = 4

mask = participants["project_id"] == "FAM"

participants.loc[mask & participants["edu_level_fam"].isin([1]), "edu_level"] = 1
participants.loc[mask & participants["edu_level_fam"].isin([2, 3]), "edu_level"] = 2
participants.loc[mask & participants["edu_level_fam"].isin([4]), "edu_level"] = 3
participants.loc[mask & participants["edu_level_fam"].isin([5]), "edu_level"] = 4

mask = participants["project_id"] == "NEMOS"

participants.loc[mask & participants["edu_level_nemos"].isin([1]), "edu_level"] = 1
participants.loc[mask & participants["edu_level_nemos"].isin([2]), "edu_level"] = 2
participants.loc[mask & participants["edu_level_nemos"].isin([3, 4]), "edu_level"] = 3
participants.loc[mask & participants["edu_level_nemos"].isin([5]), "edu_level"] = 4

# -----------------
# Harmonize occupation
# -----------------
# occupation_labels = {
#     1: "Unskilled / No work / Household duties",
#     2: "Skilled occupation",
#     3: "Professional",
#     4: "Executive / Researcher"
# }

participants["occupation"] = np.nan

mask = participants["project_id"] == "UMEC"

participants.loc[mask & participants["occupation_umec"].isin([0]), "occupation"] = 1
participants.loc[mask & participants["occupation_umec"].isin([1, 2]), "occupation"] = 2
participants.loc[mask & participants["occupation_umec"].isin([3]), "occupation"] = 3
participants.loc[mask & participants["occupation_umec"].isin([4]), "occupation"] = 4

mask = participants["project_id"] == "FAM"

participants.loc[mask & participants["occupation_fam"].isin([0]), "occupation"] = 1
participants.loc[mask & participants["occupation_fam"].isin([1, 2]), "occupation"] = 2
participants.loc[mask & participants["occupation_fam"].isin([3]), "occupation"] = 3
participants.loc[mask & participants["occupation_fam"].isin([4]), "occupation"] = 4

mask = participants["project_id"] == "NEMOS"

participants.loc[mask & participants["occupation_nemos"].isin([1, 2]), "occupation"] = 1
participants.loc[mask & participants["occupation_nemos"].isin([3]), "occupation"] = 2
participants.loc[mask & participants["occupation_nemos"].isin([4]), "occupation"] = 3
participants.loc[mask & participants["occupation_nemos"].isin([5]), "occupation"] = 4

# -----------------
# Select variables common to all datasets
# -----------------
keep_cols = [
             # demographics
             'age','sex','edu_level','occupation',
             # neuropsychology
             'DST_forward', 'DST_backward', 'GDS_15',
             'LM_imm_units', 'LM_del_units', 'LM_imm_them', 'LM_del_them', 'mmse_extended',
             'PFT', 'SFT',
             'TMT_A_time', 'TMT_B_time',
              # Genetics
             'APOE', 'ACT',	'BACE1', 'BDNF', 'CHRNA7', 'CLU', 'COMT', 'CR1', 'ERBB4', 'NRG1', 'PICALM'
]

data = participants[keep_cols].copy()

# Count number of nan values
nan_counts = data.isna().sum()
print(nan_counts)

# -----------------
# Neuropsychological profile
# -----------------

neuropsycho_vars = [
    "DST_forward", "DST_backward", "GDS_15",
    "LM_imm_units", "LM_del_units", "LM_imm_them", "LM_del_them", "mmse_extended",
    "PFT", "SFT",
    "TMT_A_time", "TMT_B_time"
]

xorig = data[neuropsycho_vars].copy()

# Remove participants with NaNs
valid_rows = ~xorig.isna().any(axis=1)
x = xorig.loc[valid_rows].to_numpy()

n, p = x.shape

# Z-score data
xz = zscore(x, axis=0, ddof=1)

# Covariance matrix
cov = xz.T @ xz / (n - 1)
e = np.linalg.eigvals(cov)

# SVD
u, s, vT = np.linalg.svd(xz, full_matrices=False)
v = vT.T

# PCA
pca = PCA()
score = pca.fit_transform(xz)
coeff = pca.components_.T
latent = pca.explained_variance_
explained = pca.explained_variance_ratio_ * 100
mu = pca.mean_

# Checks
latent_ = np.sort(e)[::-1]
print(np.column_stack([latent_, latent]))

explained_ = latent / latent.sum() * 100
print(np.column_stack([explained_, explained]))

coeff_ = v
score_ = xz @ v
# score_ = u @ np.diag(s)

# Reconstructed data
xrec = score @ coeff.T
xrec = xz @ v @ v.T


# -----------------
# Biplot
# -----------------

fig, ax = plt.subplots()

# Scores
diag = participants.loc[valid_rows, "group"].astype("category")

diag_cat = ["FHneg", "FHpos", "SCDneg", "MCIneg", "SCDpos", "MCIa", "MCIm", "AD"]

cl = np.array([
    [0.15, 0.55, 0.25],   # dark green
    [0.35, 0.75, 0.45],   # light green
    [0.45, 0.25, 0.70],   # dark purple
    [0.70, 0.40, 0.80],   # purple-pink
    [0.90, 0.75, 0.10],   # yellow
    [0.90, 0.50, 0.10],   # orange
    [0.90, 0.50, 0.10],   # orange
    [0.80, 0.25, 0.25],   # red
])

alpha = np.array([1, 1, 1, 1, 1, 1, 1, 1])  # fhneg vs fhpos

for i, group in enumerate(diag_cat):
    mask = diag == group

    if alpha[i] == 0:
        continue

    ax.scatter(
        score[mask, 0],
        score[mask, 1],
        s=10,
        color=cl[i],
        label=group
    )

# Coefficients as gray arrows
scale = np.max(np.abs(score[:, :2]))

for i, var in enumerate(neuropsycho_vars):
    ax.arrow(
        0, 0,
        coeff[i, 0] * scale,
        coeff[i, 1] * scale,
        color=[0.8, 0.8, 0.8],
        width=0.005,
        head_width=0.05,
        length_includes_head=True
    )

    ax.text(
        coeff[i, 0] * scale * 1.05,
        coeff[i, 1] * scale * 1.05,
        var,
        color=[0.5, 0.5, 0.5],
        fontsize=8
    )

ax.axhline(0, color="lightgray", linewidth=0.8)
ax.axvline(0, color="lightgray", linewidth=0.8)

ax.set_xlabel("PC1")
ax.set_ylabel("PC2")
ax.legend(loc="best")
ax.set_title("PCA biplot")
ax.grid(False)
plt.show()




# # Convert categorical variables
# categorical = ['sex','edu_level','occupation',
#                'APOE', 'ACT', 'BACE1', 'BDNF', 'CHRNA7', 'CLU', 'COMT', 'CR1', 'ERBB4', 'NRG1', 'PICALM']
#
# for col in categorical:
#     data[col] = data[col].astype("category")
#
# continuous_vars = [
#     col for col in data.columns
#     if col not in categorical
# ]
#
# x = data.copy()
#
# # -----------------
# # Run FAMD
# # -----------------
#
# famd = prince.FAMD(
#     n_components=6,
#     random_state=42
# )
#
# famd = famd.fit(x)
#
# # -----------------
# # Transform data
# # -----------------
#
# components = famd.transform(x)
#
# # -----------------
# # Explained variance
# # -----------------
#
# print("\nExplained variance ratio:")
# print(famd.percentage_of_variance_)
#
#
# # Keep only numeric continuous variables
# x = participants[continuous_vars].select_dtypes(include="number")
#
# # -----------------
# # Handle missing values
# # -----------------
#
# x = x.dropna()
#
# # -----------------
# # Standardize
# # -----------------
#
