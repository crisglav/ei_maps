import os

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

np.random.seed(42)

# -----------------------
# Config
# -----------------------

FIGS_FOLDER = os.path.join("..", "figs", "correlations")
DATA_FOLDER = os.path.join("..", "data")
RESULTS_FOLDER = os.path.join("..", "results")

RESULTS_FILE = os.path.join(
    RESULTS_FOLDER,
    "corr_apexp_receptors_wa_FAM_PYTHON_NEWSCRIPT.csv",
)

PARTICIPANTS_FILE = os.path.join(
    DATA_FOLDER,
    "participants_real.xlsx",
)

RECEPTOR_COLORS = {
    # Glutamate
    "NMDA": "#f9a825",
    "mGluR5": "#f9a825",


    # GABA
    "GABA_flumazenil": "#42a5f5",
    "GABA_a5": "#42a5f5",

    # Acetylcholine
    "ACh_a4b2": "#F06292",
    "ACh_M1": "#F06292",
}

os.makedirs(FIGS_FOLDER, exist_ok=True)

# -----------------------
# Load data
# -----------------------

results = pd.read_csv(RESULTS_FILE)
participants = pd.read_excel(PARTICIPANTS_FILE)
mask = participants["participant_id"].astype(str).str.startswith("FAM")
participants = participants[mask].copy()

participants = participants.merge(results,on="participant_id",how="left")

# -----------------------
# Plot correlations
# -----------------------
plt.figure(figsize=(10, 5))

spacing = 1.5
positions = np.arange(len(RECEPTOR_COLORS)) * spacing + 1

for i, receptor in enumerate(RECEPTOR_COLORS):

    corr_col = f"corr_{receptor}"
    pval_col = f"pval_{receptor}"

    xpos = positions[i]

    x = np.random.normal(
        loc=xpos,
        scale=0.05,
        size=len(participants),
    )

    y = participants[corr_col]
    pvals = participants[pval_col]

    significant = pvals < 0.05
    non_significant = pvals >= 0.05

    color = RECEPTOR_COLORS.get(receptor, "black")

    # Boxplot
    plt.boxplot(
        y,
        positions=[xpos],
        widths=0.35,
        patch_artist=True,
        showfliers=False,
        boxprops=dict(facecolor='none', edgecolor=color, linewidth = 1.5),
        medianprops=dict(color=color, linewidth=3),
        whiskerprops=dict(color=color, linewidth=1.5),
        capprops=dict(color=color, linewidth=1.5),
    )

    # Non-significant points
    plt.scatter(
        x[non_significant],
        y[non_significant],
        color="lightgray",
        edgecolors="none",
        alpha=0.4,
        zorder=1,
    )

    # Significant points
    plt.scatter(
        x[significant],
        y[significant],
        color=color,
        edgecolors="none",
        alpha=0.4,
        zorder = 1
    )

# Legend
plt.scatter([], [], color="lightgray", alpha=0.7,
            label="p ≥ 0.05")

plt.legend(frameon=False, loc="lower left")


# Remove ticks and labels
ax = plt.gca()
ax.set_xticks([])
ax.set_xlabel("")
ax.spines["bottom"].set_visible(False)

ax.spines["left"].set_color("gray")
ax.tick_params(axis="y", colors="gray")
ax.yaxis.label.set_color("gray")

for label in ax.get_yticklabels():
    label.set_fontname("Roboto")
    label.set_fontsize(12)   # adjust as desired

# Y-axis title
ax.set_ylabel(
    ax.get_ylabel(),
    fontname="Roboto",
    fontsize=16,             # slightly larger than tick labels
    color="gray",
)

# Padding to the left axis
plt.xlim(positions[0] - 0.8, positions[-1] + 0.8)

# Remove top and right borders
ax = plt.gca()
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

plt.ylabel("Spatial correlation (R)")

plt.axhline(
    0,
    color="gray",
    linewidth=1,
    linestyle="--",
)

plt.ylim(-0.2, 0.4)
plt.tight_layout()

# Save figure
output_file = os.path.join(
    FIGS_FOLDER,
    f"rq1_corr_apexp_receptors_FAM.svg",
)

plt.savefig(output_file, dpi=300)
plt.close()

print(f"Saved figure: {output_file}")
