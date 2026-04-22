import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

np.random.seed(42)

# Create figure folder
figs_folder = os.path.join('..', 'figs')
os.makedirs(figs_folder, exist_ok=True)

# Path to results csv
results_file = os.path.join('..', 'results', 'corr_apexp_receptors_wa_cortical_nohipo.csv')
results = pd.read_csv(results_file)

# Load participants to divide by group
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Create column group merged
participants["group_merged"] = participants["group"].replace({
    "MCIa": "MCI",
    "MCIm": "MCI",
    "CONV": "AD",
    "SCDpos": "SCD"
})

groups = ['FHpos', 'FHneg', 'SCDneg', 'MCIneg','SCD', 'MCI', 'AD']

# List receptors
receptors = ['mGluR5','NMDA','GABA_flumazenil','GABA_a5','VAChT','ACh_a4b2','ACh_M1']
receptor_colors = {
    # Glutamate
    "mGluR5":  "#ffd54f",          # light yellow
    "NMDA":    "#ffd54f",          # dark yellow
    # GABA
    "GABA_flumazenil": "#42a5f5",  # light blue
    "GABA_a5": "#42a5f5",          # dark blue
    # VAChT
    "VAChT": "#F06292",            # light pink
    "ACh_a4b2": "#F06292",
    "ACh_M1": "#F06292"            # dark pink
}

# receptors = ['dubois', 'rosaneto', 'smart', 'galovic','dukart','norgaard','lukow','aghourian','bedard','tuominen','hillmer','naganawa']
# receptor_colors = {
#     # Glutamate
#     "dubois":   "#ffd54f", #  yellow
#     "rosaneto":  "#ffd54f",
#     "smart":     "#ffd54f",
#     "galovic":    "#f9a825",
#     # GABA
#     "dukart":   "#90caf9", #  blue
#     "norgaard": "#90caf9",
#     "lukow":    "#1565c0",
#     # ACh
#     "aghourian": "#EC407A", # pink
#     "bedard":   "#EC407A",
#     "tuominen": "#EC407A",
#     "hillmer": "#F06292",
#     "naganawa": "#FF6FAF"
# }

# Merge results into participants using participant_id
participants = participants.merge(
    results,
    on="participant_id",
    how="left"
)

for group in groups:

    plt.figure(figsize=(10, 6))

    subset = participants[participants["group_merged"] == group]

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

    # Save figure
    plt.savefig(os.path.join(figs_folder, f"corr_{group}_corticaL_nohipo.png"), dpi=300)
    plt.close()

