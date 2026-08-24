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
    "corr_apexp_receptors_UMEC_20260824.csv",
)

PARTICIPANTS_FILE = os.path.join(
    DATA_FOLDER,
    "participants_20260814.xlsx",
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
mask = participants["participant_id"].astype(str).str.startswith("UMEC")
participants = participants[mask].copy()

participants = participants.merge(results,on="participant_id",how="left")

groups = ['HC','SCD','MCI']

# -----------------------
# Plot correlations
# -----------------------
fig, axes = plt.subplots(3, 1, figsize=(10, 8), sharex=True, sharey=True)

for ax, group in zip(axes, groups):

    subset = participants[participants["diagnosis"] == group]

    spacing = 1.5
    positions = np.arange(len(RECEPTOR_COLORS)) * spacing + 1

    for i, receptor in enumerate(RECEPTOR_COLORS):

        corr_col = f"corr_{receptor}"
        pval_col = f"pval_{receptor}"

        xpos = positions[i]

        x = np.random.normal(
            loc=xpos,
            scale=0.05,
            size=len(subset),
        )

        y = subset[corr_col]
        pvals = subset[pval_col]

        significant = pvals < 0.05
        non_significant = pvals >= 0.05

        color = RECEPTOR_COLORS.get(receptor, "black")

        # Boxplot
        ax.boxplot(
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
        ax.scatter(
            x[non_significant],
            y[non_significant],
            color="lightgray",
            edgecolors="none",
            alpha=0.4,
            zorder=1,
        )

        # Significant points
        ax.scatter(
            x[significant],
            y[significant],
            color=color,
            edgecolors="none",
            alpha=0.4,
            zorder = 1
        )
    # Title
    ax.set_title(group,fontname = 'Roboto', fontsize = 14)

    # Legend
    ax.scatter([], [], color="lightgray", alpha=0.7,
                label="p ≥ 0.05")
    ax.legend(frameon=False, loc="lower left")

    # Y axis
    ax.set_ylabel(
        ax.get_ylabel(),
        fontname="Roboto",
        fontsize=14,             # slightly larger than tick labels
        color="gray",
    )
    ax.set_ylim(-0.2, 0.4)
    ax.spines["left"].set_color("gray")
    ax.tick_params(axis="y", colors="gray")

    ax.yaxis.label.set_color("gray")
    for label in ax.get_yticklabels():
        label.set_fontname("Roboto")
        label.set_fontsize(12)

    # Remove X axis
    ax.tick_params(axis="x", length=0)
    ax.spines["bottom"].set_visible(False)


    # Remove top and right borders
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # Zero line
    ax.axhline(0, color="gray", linewidth=1, linestyle="--")

    # Receptor names at x axis
    axes[-1].set_xticks(positions)
    axes[-1].set_xticklabels(
        list(RECEPTOR_COLORS.keys()),
        fontname="Roboto",
        fontsize=12,
        color="gray",
        rotation=45,
        ha="right",
    )


plt.tight_layout(rect=[0.05, 0, 1, 1])

# Y axis title
fig.supylabel(
    "Spatial correlation (R)",
    x = 0.02,
    fontname="Roboto",
    fontsize=12,
    color="gray",
)

# Save figure
output_file = os.path.join(
    FIGS_FOLDER,
    f"rq3_corr_apexp_receptors_UMEC_20260717.svg",
)

plt.savefig(output_file, dpi=300)
plt.close()

print(f"Saved figure: {output_file}")
