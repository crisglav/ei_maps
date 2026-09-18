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

# -----------------------
# Config
# -----------------------
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

# Project root (fooof files)
project_root = config['path']['project_root']
fooof_path = config['path']['fooof']

# Figures folder
figs_folder = os.path.join('..', '..', 'figs','neuropsycho')
os.makedirs(figs_folder, exist_ok=True)

# Participants file
participants_path = config['path']['participants']

# Dataset
dataset = ('NEMOS')

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
stats_file = [ f for f in os.listdir(stats_folder) if dataset in f]
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
# Linear model between cluster_avg and mmse
# ------------------
x = sm.add_constant(results['cluster_avg'])
y = results['mmse_adj']

model = sm.OLS(y,x, missing='drop')
res = model.fit()

print(res.summary())

xfit = np.linspace(results['cluster_avg'].min(), results['cluster_avg'].max(), 100)
yfit = res.predict(sm.add_constant(xfit))


for diagnosis, subset in results.groupby('diagnosis'):
    plt.scatter(
        subset['cluster_avg'],
        subset['mmse_adj'],
        color=group_colors[dataset].get(diagnosis, 'gray'),
        alpha=0.7,
        s=40,
        label=diagnosis
    )

plt.plot(xfit, yfit, color='black', linewidth=2, label='Linear fit')
plt.xlabel('Aperiodic exponent')
plt.ylabel('Adjusted MMSE')
plt.title(dataset)
plt.text(0.75, 0.15, f'R² = {res.rsquared:.3f}\np = {res.pvalues["cluster_avg"]:.3g}', transform=plt.gca().transAxes, va='top')
plt.legend(title='Diagnosis', frameon=False, loc='lower left')


# Save figure
output_file = os.path.join(figs_folder, f'corr_apexp_mmse_{dataset}_20260918.svg')
plt.savefig(output_file, dpi=300, transparent=True, bbox_inches='tight')
plt.close()
print(f'Saved figure: {output_file}')
