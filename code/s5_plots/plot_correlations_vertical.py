# This scripts visualizes the individual correlations betweeen the aperiodic exponent and 6 neurotransmitter maps
#
# Cristina Gil Ávila, C3N, 10/09/2026

import os
import json
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

np.random.seed(42)

# -----------------------
# Config
# -----------------------
# Dataset
dataset = 'NEMOS'

if dataset == 'NEMOS':
    groups = ['HC', 'MCI', 'AD']
    plot_groups = True

if dataset == 'UMEC':
    groups = ['HC', 'SCD', 'MCI']
    plot_groups = True

if dataset == 'FAM':
    groups = ['HC']
    plot_groups = False

# Config file
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

# Figures folder
figs_folder = os.path.join('..', '..', 'figs','correlations')
os.makedirs(figs_folder, exist_ok=True)

# Participants file
participants_path = config['path']['participants']

# Correlations path
results_file = os.path.join('..', '..', 'results', f'corr_apexp_receptors_{dataset}_20260831.csv')

# Receptor colors
receptor_colors = {
    # Glutamate
    'NMDA': '#F06292',
    'mGluR5': '#F06292',

    # GABA
    'GABA_flumazenil': '#F06292',
    'GABA_a5': '#F06292',

    # # Acetylcholine
    # 'ACh_a4b2': '#F06292',
    # 'ACh_M1': '#F06292',
}

# -----------------------
# Load participants metadata
# -----------------------
participants = pd.read_excel(participants_path)

# Select participants for this dataset
participants = participants[participants['participant_id'].astype(str).str.startswith(dataset)].copy()

# Discard participants with poor model fit
participants = participants[participants['fooofok']==True].copy()
print(f'Filtering: keeping {len(participants)} {dataset} participants')

# -----------------------
# Load correlations
# -----------------------
results = pd.read_csv(results_file)

# Merge participant's file with correlations
results = participants.merge(results,on='participant_id',how='left')


# -----------------------
# Plot correlations
# -----------------------
ylim = {
    'mGluR5': [-0.1, 0.4],
    'NMDA': [-0.1, 0.4],
    'GABA_flumazenil': [-0.1, 0.4],
    'GABA_a5':[-0.2, 0.5],
    'ACh_a4b2': [-0.2, 0.2],
    'ACh_M1': [-0.2, 0.2]
}

fig, axes = plt.subplots(6, 1, sharex=True, figsize=(2.5, 10))
spacing = 1
positions = np.arange(len(groups)) * spacing + 1

for ax, receptor in zip(axes, receptor_colors.keys()):

    corr_col = f'corr_{receptor}'
    pval_col = f'pval_{receptor}'

    x = np.random.normal(loc=1, scale=0.05, size=len(results))
    y = results[corr_col]

    pvals = results[pval_col]
    significant = pvals < 0.05
    non_significant = pvals >= 0.05

    # Boxplot
    ax.boxplot(
        y,
        positions=[1],
        widths=0.1,
        patch_artist=True,
        showfliers=False,
        boxprops=dict(facecolor='none', edgecolor='#5A5A5A', linewidth = 1.5),
        medianprops=dict(color='#5A5A5A', linewidth=3),
        whiskerprops=dict(color='#5A5A5A', linewidth=1.5),
        capprops=dict(color='#5A5A5A', linewidth=1.5),
    )

    # Non-significant points
    ax.scatter(
        x[non_significant],
        y[non_significant],
        color='lightgray',
        edgecolors='none',
        alpha=0.4,
        zorder=1,
    )

    # Significant points
    ax.scatter(
        x[significant],
        y[significant],
        color='#F06292',
        edgecolors='none',
        alpha=0.4,
        zorder = 1
    )

    # Horizontal line
    ax.axhline(0, color='gray', linewidth=1, linestyle='--')

    # Axis limits
    ax.set_ylim(ylim[receptor])

    # X axis
    ax.set_xticks([])
    ax.set_xlabel('')
    ax.tick_params(axis="x", length=0)

# # Y axis
# ax.tick_params(axis='y', colors='gray')
# ax.yaxis.label.set_color('gray')
# for label in ax.get_yticklabels():
#     label.set_fontname('Roboto')
#     label.set_fontsize(10)
#
# # Spines
# ax.spines["top"].set_visible(False)
# ax.spines["right"].set_visible(False)
# ax.spines['left'].set_color('gray')

# Legend
axes[-1].scatter([], [], color='#F06292', alpha=0.7, label='p < 0.05')
axes[-1].scatter([], [], color='lightgray', alpha=0.7, label='p ≥ 0.05')
axes[-1].legend(frameon=True, loc='lower right', labelcolor='black', prop={'size': 10, 'family': 'Roboto'}, ncol=1)

# Save figure
output_file = os.path.join(figs_folder, f'corr_apexp_receptors_{dataset}_vertical_20260831.svg')
plt.savefig(output_file, dpi=300)
plt.close()
print(f'Saved figure: {output_file}')
