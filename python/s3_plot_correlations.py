import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from scipy import stats

# Path to results csv
results_file = os.path.join('..', 'results', 'corr_apexp_receptors.csv')

# Load dataframe
participants = pd.read_csv(results_file)

# Select receptor
receptors = ['dubois','galovic','rosaneto','smart','dukart','lukow','norgaard']

# Create figure folder
figs_folder = os.path.join('..', 'figs')
os.makedirs(figs_folder, exist_ok=True)

for receptor in receptors:

    receptor = f"corr_{receptor}"

    # # Define groups
    # groups = ["AD", "CONV", "MCIa", "MCIm", 'SCDpos', 'FHpos', 'FHneg', 'SCDneg', 'MCIneg']
    #
    # # Define colors for each group
    # group_colors = {
    #     "AD": "brown",
    #     "CONV": "brown",
    #     "MCIa": "orange",
    #     "MCIm": "orange",
    #     "SCDpos": "gold",
    #     "FHpos": "yellow",
    #     "FHneg": "greenyellow",
    #     "SCDneg": "lime",
    #     "MCIneg": "seagreen",
    #     "HC": "blue"
    # }

    groups = ["AD", "MCI", "SCD", "FH", 'HC']
    group_colors = {
        "AD": "brown",
        "MCI": "orange",
        "SCD": "gold",
        "FH": "yellow",
        "HC": "seagreen"
    }

    plt.figure(figsize=(10, 6))

    # Plot each group separately
    for i, g in enumerate(groups):
        subset = participants[participants["diagnosis"] == g]

        # x positions with jitter
        x = np.random.normal(i + 1, 0.05, size=len(subset))
        y = subset[receptor]

        plt.scatter(
            x, y,
            color=group_colors.get(g, "black"),
            label=g,
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

    # Save figure
    plt.savefig(os.path.join(figs_folder, f"{receptor}_group_scatter.png"), dpi=300)
    plt.close()


    ## Scatterplot age

    # Fit regression
    x = participants["age"]
    y = participants[receptor]

    # Fit regression
    slope, intercept, r_value, p_value, std_err = stats.linregress(x, y)

    # Create line
    x_line = np.linspace(x.min(), x.max(), 100)
    y_line = slope * x_line + intercept

    # Assign a color to each row
    colors = participants["diagnosis"].map(group_colors).fillna("black")

    # Scatter plot
    plt.figure(figsize=(10, 6))
    plt.scatter(x=x,y=y,c=colors,alpha=0.7)
    plt.plot(x_line, y_line, color="lightgray")

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

    plt.savefig(os.path.join(figs_folder, f"{receptor}_age_scatter.png"), dpi=300)
    plt.close()

    # Filter only HC group
    df = participants[participants["diagnosis"] == "HC"].dropna(subset=["age", receptor])

    # Fit regression
    x = df["age"]
    y = df[receptor]

    slope, intercept, r_value, p_value, std_err = stats.linregress(x, y)

    # Create line
    x_line = np.linspace(x.min(), x.max(), 100)
    y_line = slope * x_line + intercept

    # Scatter plot (single color since only HC)
    plt.figure(figsize=(10, 6))
    plt.scatter(x, y, color="seagreen", alpha=0.7)
    plt.plot(x_line, y_line, color="lightgray")

    # Stats text
    plt.text(
        0.05, 0.95,
        f"r = {r_value:.2f}\np = {p_value:.3e}",
        transform=plt.gca().transAxes,
        verticalalignment='top'
    )

    plt.xlabel("Age")
    plt.ylabel(receptor)
    plt.title(f"Correlation {receptor} (HC only)")

    plt.tight_layout()

    # Save
    plt.savefig(os.path.join(figs_folder, f"{receptor}_age_scatter_HC.png"), dpi=300)
    plt.close()