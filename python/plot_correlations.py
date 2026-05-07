import os

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

np.random.seed(42)

# -----------------------
# Config
# -----------------------

FIGS_FOLDER = os.path.join("..", "figs")
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

GROUPS = ["FAM"]

RECEPTORS = [
    "mGluR5",
    "NMDA",
    "GABA_flumazenil",
    "GABA_a5",
    "VAChT",
    "ACh_a4b2",
    "ACh_M1",
]

RECEPTOR_COLORS = {
    # Glutamate
    "mGluR5": "#ffd54f",
    "NMDA": "#f9a825",

    # GABA
    "GABA_flumazenil": "#42a5f5",
    "GABA_a5": "#1565c0",

    # Acetylcholine
    "VAChT": "#FF6FAF",
    "ACh_a4b2": "#F06292",
    "ACh_M1": "#EC407A",
}

os.makedirs(FIGS_FOLDER, exist_ok=True)

# -----------------------
# Load data
# -----------------------

results = pd.read_csv(RESULTS_FILE)
participants = pd.read_excel(PARTICIPANTS_FILE)

participants["group_merged"] = participants["group"].replace({
    "MCIa": "MCI",
    "MCIm": "MCI",
    "CONV": "AD",
    "SCDpos": "SCD",
})

participants = participants.merge(
    results,
    on="participant_id",
    how="left",
)

# -----------------------
# Plot correlations
# -----------------------

for group in GROUPS:

    plt.figure(figsize=(10, 6))

    # For clinical groups:
    # subset = participants[participants["group_merged"] == group]

    # For FAM subjects:
    subset = participants[
        participants["participant_id"]
        .astype(str)
        .str
        .startswith("FAM")
    ]

    for i, receptor in enumerate(RECEPTORS):

        corr_col = f"corr_{receptor}"
        pval_col = f"pval_{receptor}"

        x = np.random.normal(
            loc=i + 1,
            scale=0.05,
            size=len(subset),
        )

        y = subset[corr_col]
        pvals = subset[pval_col]

        significant = pvals < 0.05
        non_significant = pvals >= 0.05

        # Significant points
        plt.scatter(
            x[significant],
            y[significant],
            color=RECEPTOR_COLORS.get(receptor, "black"),
            alpha=0.7,
        )

        # Non-significant points
        plt.scatter(
            x[non_significant],
            y[non_significant],
            color="lightgray",
            alpha=0.7,
        )

    # Axis formatting
    plt.xticks(
        ticks=range(1, len(RECEPTORS) + 1),
        labels=RECEPTORS,
        rotation=45,
    )

    # Remove top and right borders
    ax = plt.gca()
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # plt.xlabel("Neurotransmitter map")
    plt.ylabel("R")
    # plt.title(f"Correlation between aperiodic exponents and neurotransmitter maps {group}")

    plt.axhline(
        0,
        color="black",
        linewidth=1,
        linestyle="--",
    )

    plt.ylim(-0.2, 0.4)
    plt.tight_layout()

    # Save figure
    output_file = os.path.join(
        FIGS_FOLDER,
        f"py_corr_{group}.png",
    )

    plt.savefig(output_file, dpi=300)
    plt.close()
    # plt.show()

    print(f"Saved figure: {output_file}")
