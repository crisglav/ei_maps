import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

np.random.seed(42)

# Create figure folder
figs_folder = os.path.join('../..', 'figs')
os.makedirs(figs_folder, exist_ok=True)

# Path to results csv
results_file = os.path.join('../..', 'results', 'MCI_corr_apexp_receptors_wa.csv')
results = pd.read_csv(results_file)

# Load participants to divide by group
participants_path = os.path.join('../..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# NEMOS ONLY
participants = participants[participants["participant_id"].astype(str).str.startswith("NEMOS")]

# Create column group merged
participants["group_merged"] = participants["group"].replace({
    "MCIa": "MCI_stable",
    "MCIm": "MCI_stable",
    "CONV": "MCI_conv",
    "MCIneg": "HC",
})

groups = ['HC', 'MCI_stable', 'MCI_conv']

# List receptors
receptors = ['mGluR5','NMDA','GABA_flumazenil','GABA_a5','VAChT','ACh_a4b2','ACh_M1']
receptor_colors = {
    # Glutamate
    "mGluR5":  "#ffd54f",          # light yellow
    "NMDA":    "#f9a825",          # dark yellow
    # GABA
    "GABA_flumazenil": "#42a5f5",  # light blue
    "GABA_a5": "#1565c0",          # dark blue
    # VAChT
    "VAChT": "#FF6FAF",            # light pink
    "ACh_a4b2": "#F06292",
    "ACh_M1": "#EC407A"            # dark pink
}

# Merge results into participants using participant_id
participants = participants.merge(
    results,
    on="participant_id",
    how="left"
)

plt.figure(figsize=(14, 6))

gap = 1
x_positions = []
x_labels = []

for r_i, receptor in enumerate(receptors):
    receptor_col = f"corr_{receptor}"
    pval_col = f"pval_{receptor}"

    for g_i, group in enumerate(groups):
        subset = participants[participants["group_merged"] == group]

        x_center = r_i * (len(groups) + gap) + g_i + 1
        x_positions.append(x_center)
        x_labels.append(group)

        x = np.random.normal(x_center, 0.05, size=len(subset))
        y = subset[receptor_col]
        pvals = subset[pval_col]

        sig = pvals < 0.05
        nonsig = pvals >= 0.05

        plt.scatter(
            x[sig], y[sig],
            color=receptor_colors.get(receptor, "black"),
            alpha=0.7
        )

        plt.scatter(
            x[nonsig], y[nonsig],
            color="lightgray",
            alpha=0.7
        )

# group labels on x-axis
plt.xticks(x_positions, x_labels, rotation=45)

# receptor labels above subgroup blocks
for r_i, receptor in enumerate(receptors):
    block_center = r_i * (len(groups) + gap) + (len(groups) + 1) / 2
    plt.text(
        block_center,
        0.42,
        receptor,
        ha="center",
        va="bottom",
        fontsize=10,
        fontweight="bold"
    )

plt.xlabel("Subgroup within each receptor")
plt.ylabel("Correlation with apexp")
plt.title("Correlation by subgroup for each receptor")

plt.axhline(0, color="black", linewidth=1, linestyle="--")
plt.ylim(-0.2, 0.45)

plt.tight_layout()
plt.savefig(os.path.join(figs_folder, "MCI_corr_by_receptor_and_group.png"), dpi=300)
plt.close()


    valid_groups = [g for g in [hc, stable, conv] if len(g) > 0]

    if len(valid_groups) >= 2:
        F, p = f_oneway(*valid_groups)

        anova_results.append({
            "receptor": receptor,
            "n_HC": len(hc),
            "n_MCI_stable": len(stable),
            "n_MCI_conv": len(conv),
            "F": F,
            "p": p
        })

        print(f"{receptor}: F={F:.3f}, p={p:.4f}")

anova_df = pd.DataFrame(anova_results)
print(anova_df)