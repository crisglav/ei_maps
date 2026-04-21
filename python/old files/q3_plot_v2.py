import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

np.random.seed(42)

# Path to results csv
results_file = os.path.join('../..', 'results', 'corr_apexp_receptors_ADspec.csv')

# Load dataframe
participants = pd.read_csv(results_file)

# Select receptor
receptors = ['dubois','galovic','rosaneto','smart','dukart','lukow','norgaard']

# Create figure folder
figs_folder = os.path.join('../..', 'figs')
os.makedirs(figs_folder, exist_ok=True)

groups = ['SCD', 'MCI', 'AD']
receptor_colors = {
    # Glutamate
    "dubois":   "#fff176",  # light yellow
    "galovic":  "#ffd54f",
    "rosaneto": "#ffca28",
    "smart":    "#f9a825",  # darker yellow
    # GABA
    "dukart":   "#90caf9",  # light blue
    "lukow":    "#42a5f5",
    "norgaard": "#1565c0"   # dark blue
}

for group in groups:

    plt.figure(figsize=(10, 6))

    subset = participants[participants["diagnosis"] == group]

    for i, receptor in enumerate(receptors):
        receptor_col = f"corr_{receptor}"
        pval = receptor_col.replace("corr_", "pval_")

        # Add jitter
        x = np.random.normal(i + 1, 0.05, size=len(subset))
        y = subset[receptor_col]
        pvals = subset[pval]

        # Significant points
        sig = pvals < 0.05
        plt.scatter(
            x[sig], y[sig],
            color=receptor_colors.get(receptor, "black"),
            label=group,
            alpha=0.7
        )
        # Non-significant points (gray)
        nonsig = pvals >= 0.05
        plt.scatter(
            x[nonsig], y[nonsig],
            color="lightgray",
            alpha=0.7
        )

    # Axis formatting
    plt.xticks(range(1, len(receptors) + 1), receptors)
    plt.xlabel("Receptors")
    plt.ylabel('Correlation with apexp')
    plt.title(f"Correlation {group}")

    plt.axhline(0, color="black", linewidth=1, linestyle="--")
    plt.ylim(-0.2, 0.4)
    plt.xticks(range(1, len(receptors) + 1), receptors, rotation=45)

    plt.tight_layout()
    plt.show()

    # # Save figure
    # plt.savefig(os.path.join(figs_folder, f"q3_{group}.png"), dpi=300)
    # plt.close()

