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
    'NMDA': '#f9a825',
    'mGluR5': '#f9a825',

    # GABA
    'GABA_flumazenil': '#42a5f5',
    'GABA_a5': '#42a5f5',

    # Acetylcholine
    'ACh_a4b2': '#F06292',
    'ACh_M1': '#F06292',
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
if plot_groups:
    fig, axes = plt.subplots(6, 1, figsize=(3, 10), sharex=True, sharey=True)
    spacing = 1
    positions = np.arange(len(groups)) * spacing + 1

    for ax, receptor in zip(axes, receptor_colors.keys()):

        corr_col = f'corr_{receptor}'
        pval_col = f'pval_{receptor}'

        for i, group in enumerate(groups):
            subset = results[results['diagnosis'] == group]

            xpos = positions[i]
            x = np.random.normal(loc=xpos, scale=0.05, size=len(subset))
            y = subset[corr_col]

            pvals = subset[pval_col]
            significant = pvals < 0.05
            non_significant = pvals >= 0.05

            color = receptor_colors.get(receptor, 'black')

            # Boxplot
            ax.boxplot(
                y,
                positions=[xpos],
                widths=0.2,
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
                color=color,
                edgecolors='none',
                alpha=0.4,
                zorder = 1
            )

        # Horizontal line
        ax.axhline(0, color='gray', linewidth=1, linestyle='--')

        # Legend
        # ax.scatter([], [], color='lightgray', alpha=0.7, label='p ≥ 0.05')
        # ax.legend(frameon=False, loc='lower left', labelcolor='gray', prop={'size': 10, 'family': 'Roboto'})

        # X axis
        ax.set_xticks([])
        ax.set_xlabel('')
        ax.spines['bottom'].set_visible(False)
        ax.tick_params(axis="x", length=0)

        # Group names at x axis
        axes[-1].set_xticks(positions)
        axes[-1].set_xticklabels(groups, fontname='Roboto', fontsize=10, color='gray')

        # Y axis
        ax.tick_params(axis='y', colors='gray')
        ax.yaxis.label.set_color('gray')
        for label in ax.get_yticklabels():
            label.set_fontname('Roboto')
            label.set_fontsize(10)

        # Spines
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.spines['left'].set_color('gray')

        # Axis limits
        ax.set_ylim(-0.25, 0.45)

        ax.set_title(receptor, fontname='Roboto', fontsize=10, color='gray')

    plt.subplots_adjust(left=0.22, right=0.98, bottom=0.02, top=0.98, hspace=0.2, wspace=0)
    fig.supylabel('Correlation (R)', fontname='Roboto', fontsize=11, color='gray')

    # Save figure
    output_file = os.path.join(figs_folder, f'corr_apexp_receptors_{dataset}_20260831.svg')
    plt.savefig(output_file, dpi=300)
    plt.close()
    print(f'Saved figure: {output_file}')



else:
    fig, axes = plt.subplots(1, 1, figsize=(6, 4))
    axes = [axes]
    
    for ax, group in zip(axes, groups):
        spacing = 1.5
        positions = np.arange(len(receptor_colors)) * spacing + 1

        for i, receptor in enumerate(receptor_colors):

            corr_col = f'corr_{receptor}'
            pval_col = f'pval_{receptor}'

            xpos = positions[i]
            x = np.random.normal(loc=xpos, scale=0.05,size=len(results))
            y = results[corr_col]

            pvals = results[pval_col]
            significant = pvals < 0.05
            non_significant = pvals >= 0.05

            color = receptor_colors.get(receptor, 'black')

            # Boxplot
            ax.boxplot(
                y,
                positions=[xpos],
                widths=0.35,
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
                color=color,
                edgecolors='none',
                alpha=0.4,
                zorder = 1
            )

        # Horizontal line
        ax.axhline(0, color='gray', linewidth=1, linestyle='--')

        # Legend
        ax.scatter([], [], color='lightgray', alpha=0.7, label='p ≥ 0.05')
        ax.legend(frameon=False, loc='lower left', labelcolor='gray', prop={'size': 10, 'family': 'Roboto'})

        # X axis
        ax.set_xticks([])
        ax.set_xlabel('')
        ax.spines['bottom'].set_visible(False)
        ax.tick_params(axis="x", length=0)

        # Receptor names at x axis (hardcoded)
        axes[-1].set_xticks(positions)
        axes[-1].set_xticklabels(['Glu_NMDA', 'Glu_mGluR5', 'GABA_bzd', 'GABA_a5', 'ACh_a4b2', 'ACh_m1'], fontname='Roboto', fontsize=10, color='gray', rotation=45,
                                 ha='right', )

        # Y axis
        ax.tick_params(axis='y', colors='gray')
        ax.yaxis.label.set_color('gray')
        for label in ax.get_yticklabels():
            label.set_fontname('Roboto')
            label.set_fontsize(10)
        ax.set_ylabel('Spatial correlation (R)', fontname='Roboto', fontsize=10, color='gray')

        # Spines
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.spines['left'].set_color('gray')

        # Axis limits
        ax.set_ylim(-0.25, 0.4)

    plt.tight_layout(rect=[0.05, 0, 1, 1])

    # Save figure
    output_file = os.path.join(figs_folder, f'corr_apexp_receptors_{dataset}_20260831.svg')
    plt.savefig(output_file, dpi=300)
    plt.close()
    print(f'Saved figure: {output_file}')
