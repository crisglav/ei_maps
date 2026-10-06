# This scripts performs statistics on the dataset's demographics
#
# Cristina Gil Ávila, C3N, 17/09/2026

import os
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# -----------------------
# Config
# -----------------------
# Dataset
datasets = ['NEMOS','UMEC','FAM']

# Group colors
group_colors = {
    'HC': '#43A047',
    'FH': '#2E7D32',
    'SCD': '#FDD835',
    'MCI': '#FB8C00',
    'AD': '#8B0000',
}
group_labels = {'HC': 'Healthy',
                'FH':'Healthy with AD family',
                'SCD': 'SCD',
                'MCI': 'MCI',
                'AD': 'AD'}

# Config file
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

# Participants file
participants_path = config['path']['participants']

participants = pd.read_excel(participants_path)

figs_folder = os.path.join('..', '..', 'figs','demographics')
os.makedirs(figs_folder, exist_ok=True)

# Plot
fig, ax = plt.subplots(figsize=(2.8, 1.8))
spacing = 0.95
for i, dataset in enumerate(datasets):

    dataset_participants = participants[
        participants['participant_id'].astype(str).str.startswith(dataset)
    ].copy()
    y = i * spacing
    left = 0

    for group in group_colors.keys():

        subset = dataset_participants[
            dataset_participants['diagnosis'] == group
        ]

        n = len(subset)

        if n > 0:
            ax.barh(
                y=y,
                width=n,
                left=left,
                height=0.4,
                color=group_colors[group],
                edgecolor='white',
                linewidth=1,
                alpha=0.7,
            )

            # Add N inside the segment
            ax.text(
                left + n / 2,
                y,
                group_labels[group],
                ha='center',
                va='center',
                fontsize=8,
                fontname = 'Roboto'
            )

            left += n

ax.set_yticks(np.arange(len(datasets)) * spacing)
# ax.set_yticklabels(datasets, fontsize = 8, fontname = 'Roboto', color = '#9d9d9c')
ax.set_yticklabels([])

ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.spines['left'].set_visible(False)
ax.tick_params(axis='y', left=False)
ax.spines['bottom'].set_color('#B2B2B2')
ax.tick_params(axis='x', labelsize = 8, colors = '#B2B2B2')
for label in ax.get_xticklabels():
    label.set_fontname('Roboto')
ax.set_xlabel('Number of participants', fontname='Roboto', fontsize=8, color = '#B2B2B2')

# plt.tight_layout()

# Save figure
output_file = os.path.join(figs_folder, f'demographics_30092026.svg')
plt.savefig(output_file, dpi=300, transparent=True, bbox_inches='tight')
plt.close()
print(f'Saved figure: {output_file}')