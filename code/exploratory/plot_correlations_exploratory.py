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
dataset = 'FAM'

if dataset == 'NEMOS':
    groups = ['HC', 'MCI', 'AD']
    plot_groups = True

if dataset == 'UMEC':
    groups = ['HC', 'SCD', 'MCI']
    plot_groups = True

if dataset == 'FAM':
    groups = ['HC']
    plot_groups = True

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
    'NMDA': '#f9a825',
    'mGluR5': '#ffd54f',

    # GABA
    'GABA_flumazenil': '#42a5f5',
    'GABA_a5': '#90caf9',

    # Acetylcholine
    'ACh_a4b2': '#F06292',
    'ACh_M1': '#F8BBD0',
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

# Sort values by corr_NMDA
results_sorted = results.copy()
results_sorted = results.sort_values(by="corr_NMDA").reset_index(drop=True)

# -----------------------
# Plot correlations
# -----------------------
# fig, ax = plt.subplots(figsize=(8, 8), sharex=True, sharey=True)
#
# x = np.arange(len(results_sorted))
# for receptor in receptor_colors.keys():
#     pvals = results_sorted[f'pval_{receptor}']
#     y = results_sorted[f'corr_{receptor}']
#     ax.scatter(
#         x,y,
#         color=receptor_colors[receptor],
#         label=receptor,
#         s=12,
#         alpha=0.8
#     )
#
# ax.set_xlabel('Participant ID')
# ax.set_ylabel('Receptor value')
#
# ax.set_xticks(x)
# ax.set_xticklabels(
#     results_sorted['participant_id'],
#     rotation=90,
#     fontsize=6
# )
#
# ax.legend(frameon=False, ncol=3)
# ax.spines[['top', 'right']].set_visible(False)
#
# plt.tight_layout()

# -----------------------
# Add second order regressions
# -----------------------
from numpy.polynomial import Polynomial

# receptor categories, already ordered by NMDA
receptors = list(receptor_colors.keys())

fig, ax = plt.subplots(figsize=(8, 8))
x = np.arange(len(results_sorted))

for receptor in receptors:

    # Scatter
    y = results_sorted[f'corr_{receptor}']
    ax.scatter(
        x,y,
        color=receptor_colors[receptor],
        label=receptor,
        s=12,
        alpha=0.8
    )

    # Non-linear (quadratic) regression
    model = Polynomial.fit(x, y, deg=2)

    # Smooth x-axis for plotting
    x_curve = np.linspace(x.min(), x.max(), 200)
    y_curve = model(x_curve)

    # Plot regression curve
    ax.plot(
        x_curve,
        y_curve,
        linewidth=2,
        color=receptor_colors[receptor],
        linestyle='-.',
        label='_nolegend_'
    )

ax.set_xlabel('Participant ID')
ax.set_ylabel('Receptor value')

ax.set_xticks(x)
ax.set_xticklabels(
    results_sorted['participant_id'],
    rotation=90,
    fontsize=6
)

ax.legend(frameon=False, ncol=3)
ax.spines[['top', 'right']].set_visible(False)

plt.tight_layout()
plt.show()