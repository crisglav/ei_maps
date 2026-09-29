# This scripts performs statistics on the dataset's demographics
#
# Cristina Gil Ávila, C3N, 17/09/2026

import os
import json
import numpy as np
import pandas as pd


# -----------------------
# Config
# -----------------------
# Dataset
datasets = ['NEMOS', 'UMEC', 'FAM']

# Group colors
group_colors = {
    'HC': '#43A047',
    'SCD': '#FDD835',
    'MCI': '#FB8C00',
    'AD': '#8B0000',
    'FH': '#757575'
}

# Config file
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

# Participants file
participants_path = config['path']['participants']

# -----------------------
# Load participants metadata
# -----------------------
participants = pd.read_excel(participants_path)


fig, ax = plt.subplots(figsize=(5, 4))

for i, dataset in enumerate(datasets):

    dataset_participants = participants[
        participants['participant_id'].astype(str).str.startswith(dataset)
    ].copy()

    bottom = 0

    for group in groups:

        subset = dataset_participants[
            dataset_participants['diagnosis'] == group
        ]

        n = len(subset)

        if n > 0:
            ax.bar(
                i,
                n,
                bottom=bottom,
                width=0.6,
                color=group_colors[group],
                edgecolor='white',
                linewidth=1
            )

            # Add N inside the segment
            ax.text(
                i,
                bottom + n / 2,
                str(n),
                ha='center',
                va='center',
                fontsize=9
            )

            bottom += n

ax.set_xticks(range(len(datasets)))
ax.set_xticklabels(datasets)

ax.set_ylabel('Number of participants')

ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

plt.tight_layout()
plt.show()





for dataset in ['NEMOS', 'UMEC', 'FAM']:
    # Select participants for this dataset
    participants = participants[participants['participant_id'].astype(str).str.startswith(dataset)].copy()

    # Print on screen all variables
    for group in groups:
        # if dataset == 'FAM':
        #     subset = participants.copy()
        # else:
        #
        subset = participants[participants['diagnosis'] == group]

        print(dataset)
        print(group)

        print(f"Sample size: {len(subset)}")
        print(f"Sex: {np.sum(subset['sex'] == 'f')} f, {np.sum(subset['sex'] == 'm')} m")
        print(f"Age: {np.mean(subset['age']):.1f} ± {np.std(subset['age']):.1f}")
        print(f"MMSE adj: {np.mean(subset['mmse_adj']):.1f} ± {np.std(subset['mmse_adj']):.1f}")
        print(f"Edu years: {np.mean(subset['edu_years']):.1f} ± {np.std(subset['edu_years']):.1f}")
        carriers = subset['APOE'].astype(str).str.contains('4', na=False)
        print(f"APOE: {carriers.sum()} carriers, {(~carriers).sum()} non-carriers")

