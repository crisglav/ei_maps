import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from scipy import stats

# Path to results csv
results_file = os.path.join('..', 'results', 'corr_apexp_receptors_HC.csv')

# Load dataframe
participants = pd.read_csv(results_file)

# Select receptor
receptors = ['dubois','galovic','rosaneto','smart','dukart','lukow','norgaard']

# Create figure folder
figs_folder = os.path.join('..', 'figs')
os.makedirs(figs_folder, exist_ok=True)

for receptor in receptors:

    receptor = f"corr_{receptor}"
    pval = receptor.replace("corr_", "pval_")

    groups = ['FHpos', 'FHneg', 'SCDneg', 'MCIneg']
    group_colors = {
        "FHpos": "#a5d6a7",
        "FHneg": "#66bb6a",
        "SCDneg": "#388e3c",
        "MCIneg": "#1b5e20"
    }

    plt.figure(figsize=(10, 6))

    # Plot each group separately
    for i, g in enumerate(groups):
        subset = participants[participants["group"] == g]

        # x positions with jitter
        x = np.random.normal(i + 1, 0.05, size=len(subset))
        y = subset[receptor]
        pvals = subset[pval]

        # Significant points
        sig = pvals < 0.05
        plt.scatter(
            x[sig], y[sig],
            color=group_colors.get(g, "black"),
            label=g,
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
    plt.xticks(range(1, len(groups) + 1), groups)
    plt.xlabel("Group")
    plt.ylabel(receptor)
    plt.title(f"Correlation {receptor}")

    # Remove duplicate legend entries
    handles, labels = plt.gca().get_legend_handles_labels()
    by_label = dict(zip(labels, handles))
    plt.legend(by_label.values(), by_label.keys(), title="Group")

    plt.tight_layout()
    # plt.show()

    # Save figure
    plt.savefig(os.path.join(figs_folder, f"q1_{receptor}.png"), dpi=300)
    plt.close()


    ## Scatterplot age
    x = participants["age"]
    y = participants[receptor]
    pvals = participants[pval]

    # Fit regression
    x_sig = x[pvals<0.05]
    y_sig = y[pvals<0.05]
    slope, intercept, r_value, p_value, std_err = stats.linregress(x_sig, y_sig)

    # Create line
    x_line = np.linspace(x_sig.min(), x_sig.max(), 100)
    y_line = slope * x_line + intercept

    # Assign a color to each row
    colors = participants["group"].map(group_colors).fillna("black")
    colors = np.where(pvals >= 0.05, "lightgray", colors)

    # Scatter plot
    plt.figure(figsize=(10, 6))
    plt.scatter(x=x,y=y,c=colors,alpha=0.7)

    # Regression line
    plt.plot(x_line, y_line, color="#1b5e20", alpha=0.7)

    plt.text(
        0.05, 0.95,
        f"r = {r_value:.2f}\np = {p_value:.3e}",
        transform=plt.gca().transAxes,
        verticalalignment='top'
    )

    plt.xlabel("Age")
    plt.ylabel(receptor)
    plt.title(f"Correlation {receptor}")
    plt.legend(title="Group")

    plt.tight_layout()

    plt.savefig(os.path.join(figs_folder, f"q1_age_{receptor}.png"), dpi=300)
    plt.close()

