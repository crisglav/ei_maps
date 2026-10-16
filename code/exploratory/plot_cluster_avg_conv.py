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
figs_folder = os.path.join('..', '..', 'figs', 'cluster_avg')
os.makedirs(figs_folder, exist_ok=True)

# Participants file
participants_path = config['path']['participants_ageL1']

# Dataset
dataset = 'NEMOS'

# Define colors
group_colors = {
    "MCIstable": "#FB8C00",
    "MCIconv": "#795548"
}

# -----------------------
# Load participants metadata
# -----------------------
participants = pd.read_excel(participants_path)

# Select participants for this dataset
participants = participants[participants['participant_id'].astype(str).str.startswith(dataset)].copy()

# Filter participants with MCI and information about converstion
participants = participants[(participants['diagnosis']=='MCI') & (participants['converter'].isin([0,1]))].copy()
print(f'Filtering: keeping {len(participants)} {dataset} participants')

# Discard participants with poor model fit
participants = participants[participants['fooofok']==True].copy()
print(f'Filtering: keeping {len(participants)} {dataset} participants')

# Create a new column
participants['converter_name'] = np.where(participants['converter'] == 0, 'MCIstable','MCIconv')

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
stats_folder = os.path.join('..', '..', 'results', 'stats', 'ancova')
stats_file = [f for f in os.listdir(stats_folder) if f'convancova_{dataset}' in f]
stats_file = os.path.join(stats_folder, stats_file[0])
statdata = sio.loadmat(stats_file, squeeze_me=True, struct_as_record=False)

# Get the cluster significant positions
sigmask = getattr(statdata['stats'],'prob')
sigmask = sigmask < 0.1


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
# T-test on residuals after regressing age
# ------------------
# Regress out age from the aperiodic exponent
data = results[['cluster_avg', 'converter', 'age']].dropna().copy()

model = smf.ols('cluster_avg ~ age', data=data).fit()
data['cluster_avg_resid'] = model.resid

# Two-sided independent-samples t-test
group0 = data.loc[data['converter'] == 0, 'cluster_avg_resid']
group1 = data.loc[data['converter'] == 1, 'cluster_avg_resid']

tstat, pval = stats.ttest_ind(group0, group1, alternative='two-sided', equal_var=False)

# Cohen's d (pooled standard deviation)
n0, n1 = len(group0), len(group1)
s0, s1 = group0.std(ddof=1), group1.std(ddof=1)

pooled_sd = np.sqrt(
    ((n0 - 1) * s0**2 + (n1 - 1) * s1**2) /
    (n0 + n1 - 2)
)

cohens_d = (group1.mean() - group0.mean()) / pooled_sd

# Print results
print(f't = {tstat:.3f}, p = {pval:.7f}')
print(f"Cohen's d = {cohens_d:.3f}")
print(f'MCIstable: n = {n0}, mean residual = {group0.mean():.4f}')
print(f'MCIconv: n = {n1}, mean residual = {group1.mean():.4f}')

# -----------------
# Plot cluster_avg individual values
# ------------------
fig, ax = plt.subplots(figsize=(3, 2))

spacing = 1
groups = list(group_colors.keys())
positions = np.arange(len(groups)) * spacing + 1

for i, group in enumerate(groups):

    xpos = positions[i]

    # Data for this diagnosis
    y = results.loc[results['converter_name'] == group,'cluster_avg'].values

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
        color=group_colors[group],
        edgecolors='none',
        alpha=0.7,
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
output_file = os.path.join(figs_folder, f'cluster_avg_{dataset}_conv_20260918.svg')
plt.savefig(output_file, dpi=300, transparent=True, bbox_inches='tight')
plt.close()
print(f'Saved figure: {output_file}')