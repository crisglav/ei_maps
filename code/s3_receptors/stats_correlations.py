# This scripts performs statistics on the correlations'distribtions (betweeen the aperiodic exponent and 6 neurotransmitter maps)
#
# Cristina Gil Ávila, C3N, 17/09/2026

import os
import json
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats

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
    plot_groups = False

# Config file
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

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
# Percentage of significant correlations
# -----------------------
if plot_groups:
    fig, axes = plt.subplots(3, 1, figsize=(6, 8), sharex=True, sharey=True)
else:
    fig, axes = plt.subplots(1, 1, figsize=(6, 4))
    axes = [axes]

for ax, group in zip(axes, groups):
    if plot_groups:
        subset = results[results['diagnosis'] == group]
    else:
        subset = results

    for i, receptor in enumerate(receptor_colors):

        corr_col = f'corr_{receptor}'
        pval_col = f'pval_{receptor}'

        y = results[corr_col]

        pvals = results[pval_col]
        significant = pvals < 0.05
        non_significant = pvals >= 0.05

        color = receptor_colors.get(receptor, 'black')

        persig = (sum((significant)) / len(significant)) * 100
        pernonsig = (sum(non_significant) / len(non_significant)) * 100
        medianR = np.median(y)
        iqrR = stats.iqr(y)

        print(f'{receptor}: significant {persig:.2f}%, ({pernonsig:.2f})%, medianR {medianR:.2f} ({iqrR:.2f})')

