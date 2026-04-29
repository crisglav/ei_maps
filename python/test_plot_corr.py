import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

np.random.seed(42)

# Create figure folder
figs_folder = os.path.join('..', 'figs')
os.makedirs(figs_folder, exist_ok=True)

# Path to results csv
maps_parcellated = os.path.join(
    '..', 'data', 'receptors', 'aal_spm8', 'rec_maps_aalspm8.csv'
)

# Load CSV
maps = pd.read_csv(maps_parcellated)

# Keep first 7 columns
cols = maps.columns[7:]

# Colors
colors = plt.cm.tab10.colors[:7]

plt.figure(figsize=(10, 6))

for i, col in enumerate(cols):
    y = maps[col].dropna().values

    # jitter around x=i
    x = np.random.normal(loc=i, scale=0.08, size=len(y))

    plt.scatter(
        x,
        y,
        color=colors[i],
        alpha=0.7,
        s=35
    )

# X axis labels = column names
plt.xticks(range(len(cols)), cols, rotation=45, ha='right')

plt.ylabel("Value")
plt.title("Scatter Plot with Jitter")
plt.tight_layout()

# Save
# plt.savefig(os.path.join(figs_folder, "scatter_jitter_columns.png"), dpi=300)
plt.show()