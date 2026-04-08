import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Path to results csv
results_file = os.path.join('..', 'results', 'corr_apexp_receptors.csv')

# Load dataframe
participants = pd.read_csv(results_file)

# Drop rows without correlation
participants = participants.dropna(subset=["corr_dubois"]).copy()

# Sort by correlation
participants = participants.sort_values("corr_dubois").reset_index(drop=True)

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
    y = subset["corr_dubois"]

    plt.scatter(
        x, y,
        color=group_colors.get(g, "black"),
        label=g,
        alpha=0.7
    )

# Axis formatting
plt.xticks(range(1, len(groups) + 1), groups)
plt.xlabel("Group")
plt.ylabel("Correlation")
plt.title("Correlation by group")

# Remove duplicate legend entries
handles, labels = plt.gca().get_legend_handles_labels()
by_label = dict(zip(labels, handles))
plt.legend(by_label.values(), by_label.keys(), title="Group")

plt.tight_layout()
plt.show()

## Violin plots per group

# Get groups in consistent order
groups = sorted(participants["group"].unique())

# Prepare data for violin plot
data = [participants[participants["group"] == g]["corr_dubois"] for g in groups]

# Plot
plt.figure(figsize=(8, 6))
plt.violinplot(data, showmeans=True, showmedians=True)

# Labels
plt.xticks(range(1, len(groups) + 1), groups)
plt.ylabel("Correlation")
plt.title("Correlation distribution per group")

plt.tight_layout()
plt.show()

## Scatterplot age

# Assign a color to each row
colors = participants["diagnosis"].map(group_colors).fillna("black")

# Scatter plot
plt.figure(figsize=(10, 6))
plt.scatter(
    x=participants["age"],
    y=participants["corr_dubois"],
    c=colors
)

plt.xlabel("Age")
plt.ylabel("Correlation")
plt.title("Correlation vs Age by Group")
plt.legend(title="Group")

plt.tight_layout()
plt.show()