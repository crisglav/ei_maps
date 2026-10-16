# This script correlates average apexp at significant cluster with mmse values
#
# Cristina Gil Avila

import os
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import statsmodels.api as sm
import scipy.io as sio
import statsmodels.api as sm
from scipy import stats
import seaborn as sns
import statsmodels.formula.api as smf
from statsmodels.stats.multitest import multipletests
from scipy.stats import t
from statsmodels.stats.multicomp import pairwise_tukeyhsd

# -----------------------
# Config
# -----------------------
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

# Project root (fooof files)
project_root = config['path']['project_root']
fooof_path = config['path']['fooof']

# Figures folder
figs_folder = os.path.join('..', '..', 'figs','cluster_avg')
os.makedirs(figs_folder, exist_ok=True)

# Participants file
participants_path = config['path']['participants']

# Dataset
dataset = 'UMEC'

# Variable
variable = 'mmse_adj'

# Define colors
group_colors = {
    "NEMOS": {
        "HC": "#43A047",
        "MCI": "#FB8C00",
        "AD": "#8B0000"
    },
    "UMEC": {
        "HC": "#43A047",
        "SCD": "#FDD835",
        "MCI": "#FB8C00"
    },
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

# Create dictionary
participant_info = (participants.set_index('participant_id')[['diagnosis','session']].to_dict('index'))

# -----------------------
# Locate apexp files
# -----------------------
apexp_files = {}

for pid, info in participant_info.items():
    session = info['session']

    apexp_folder = os.path.join(project_root, session, fooof_path)

    files = [
        os.path.join(apexp_folder, f)
        for f in os.listdir(apexp_folder)
        if f.endswith('imp.mat')
        and f.split('_')[0] == pid
    ]

    apexp_files[pid] = files[0] if files else None

# -----------------------
# Load matlab stats
# -----------------------
stats_folder = os.path.join('..', '..', 'results','stats','ancova')
stats_file = [f for f in os.listdir(stats_folder) if f'ancova_{dataset}' in f]
stats_file = os.path.join(stats_folder, stats_file[0])
statdata = sio.loadmat(stats_file, squeeze_me=True, struct_as_record=False)

# Get the cluster significant positions
sigmask = getattr(statdata['stats'],'mask')
sigmask = sigmask == 1


# -----------------------
# Load apexp data and average cluster significant values
# -----------------------
cluster_avg = {
    pid: {'participant_id': pid}
    for pid in participants['participant_id']
}

for pid, apexp_file in apexp_files.items():

    # Load apexp data (1D, Nsources)
    fooofdata = sio.loadmat(apexp_file, squeeze_me=True, struct_as_record=False)
    apexp = fooofdata['apexp_imp']

    # Extract apexp in significant cluster and average across positions
    apexp_sig = apexp[sigmask]
    cluster_avg[pid] = np.nanmean(apexp_sig, axis=0)

# Dict to dataframe
cluster_avg = pd.DataFrame(cluster_avg.items(), columns=['participant_id', 'cluster_avg'])

# Merge cluster_avg with participants
results = participants.merge(cluster_avg,on='participant_id',how='left')

# -----------------
# ANCOVA
# ------------------
# ANCOVA
ancova_data = results[['cluster_avg', 'diagnosis', 'age']].dropna()
model = smf.ols('cluster_avg ~ C(diagnosis) + age',data=ancova_data).fit()
ancova = sm.stats.anova_lm(model, typ=2)
print(ancova)

# Post-hoc
fstat = ancova.loc['C(diagnosis)', 'F']
pval = ancova.loc['C(diagnosis)', 'PR(>F)']
print(f'F = {fstat:.2f}, p = {pval:.7f}')

if pval < 0.05:
    print("ANOVA significant")
    tukey = pairwise_tukeyhsd(
        endog=ancova_data['cluster_avg'],
        groups=ancova_data['diagnosis'],
        alpha=0.05
    )
    print(tukey)


# -----------------
# Plot cluster_avg individual values
# ------------------
fig, ax = plt.subplots(figsize=(3, 2))

spacing = 1
groups = list(group_colors[dataset].keys())
positions = np.arange(len(groups)) * spacing + 1

for i, group in enumerate(groups):

    xpos = positions[i]

    # Data for this diagnosis
    y = results.loc[results['diagnosis'] == group,'cluster_avg'].values

    # Jittered x positions
    x = np.random.normal(loc=xpos, scale=0.05, size=len(y))

    # Boxplot
    ax.boxplot(
        y,
        positions=[xpos],
        widths=0.25,
        patch_artist=True,
        showfliers=False,
        boxprops=dict(facecolor='none',edgecolor='#5A5A5A',linewidth=1.5),
        medianprops=dict(color='#5A5A5A',linewidth=3),
        whiskerprops=dict(color='#5A5A5A',linewidth=1.5),
        capprops=dict(color='#5A5A5A',linewidth=1.5))

    # Raw data
    ax.scatter(x,y,
        color=group_colors[dataset][group],
        edgecolors='none',
        alpha=0.4,
        zorder=1,
    )

ax.set_xticks(positions)
ax.set_xticklabels(groups)
ax.set_ylabel('Aperiodic exponent', fontname='Roboto', fontsize=10, color='#9d9d9c')

ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.spines['left'].set_color('#9d9d9c')
ax.spines['bottom'].set_color('#9d9d9c')
ax.tick_params(axis='both', colors='#9d9d9c')

ax.xaxis.label.set_fontsize(10)
ax.yaxis.label.set_fontsize(10)
plt.rcParams['font.family'] = 'Roboto'
plt.rcParams['font.size'] = 10

# Save figure
output_file = os.path.join(figs_folder, f'cluster_avg_{dataset}_20260918.svg')
plt.savefig(output_file, dpi=300, transparent=True, bbox_inches='tight')
plt.close()
print(f'Saved figure: {output_file}')