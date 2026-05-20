import os

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# -------------------------
# Load participants
# -------------------------

participants_path = os.path.join(
    "..", "data", "participants_real.xlsx"
)

participants = pd.read_excel(participants_path)

# Convert to categorical
participants["group"] = participants["group"].astype("category")
participants["sex"] = participants["sex"].astype("category")
participants["diagnosis"] = participants["diagnosis"].astype("category")

# -------------------------
# Boxplot of age by group
# -------------------------

group_cats = participants["group"].cat.categories

age_data = [
    participants.loc[participants["group"] == g, "age"].dropna()
    for g in group_cats
]

plt.figure(figsize=(10, 6))

plt.boxplot(age_data, labels=group_cats)

plt.ylabel("Age")
plt.xlabel("Group")
plt.title("Age by Group")

# Remove top/right borders
ax = plt.gca()
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

plt.tight_layout()

# -------------------------
# Barplot of sex distribution by group
# -------------------------

sex_cats = participants["sex"].cat.categories

count_mat = np.zeros((len(group_cats), len(sex_cats)))

for ig, group in enumerate(group_cats):

    idx_g = participants["group"] == group

    for isx, sex in enumerate(sex_cats):

        count_mat[ig, isx] = np.sum(
            participants.loc[idx_g, "sex"] == sex
        )

x = np.arange(len(group_cats))
width = 0.8 / len(sex_cats)

plt.figure(figsize=(10, 6))

for isx, sex in enumerate(sex_cats):

    plt.bar(
        x + isx * width,
        count_mat[:, isx],
        width=width,
        label=sex,
    )

plt.xticks(
    x + width * (len(sex_cats) - 1) / 2,
    group_cats,
    rotation=45,
)

plt.xlabel("Group")
plt.ylabel("Count")
plt.title("Sex Distribution by Group")
plt.legend(title="Sex")

# Remove top/right borders
ax = plt.gca()
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

plt.tight_layout()
plt.show()

import statsmodels.api as sm
from statsmodels.formula.api import ols
from scipy.stats import f_oneway

# -------------------------
# Exclude FH groups
# -------------------------

exclude_groups = ["FHpos", "FHneg"]

participants_anova = participants[
    ~participants["group"].isin(exclude_groups)
].copy()

# -------------------------
# One-way ANOVA with scipy
# -------------------------

group_cats_anova = (
    participants_anova["group"]
    .dropna()
    .unique()
)

age_groups = [
    participants_anova.loc[
        participants_anova["group"] == g,
        "age"
    ].dropna().values
    for g in group_cats_anova
]

F, p = f_oneway(*age_groups)

print("One-way ANOVA: Age by Group (excluding FHpos/FHneg)")
print(f"F statistic = {F:.4f}")
print(f"p-value     = {p:.6f}")