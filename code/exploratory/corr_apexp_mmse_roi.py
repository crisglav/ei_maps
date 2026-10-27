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
from scipy.stats import pearsonr
from scipy import stats
from statsmodels.formula.api import ols
import statsmodels.stats.anova as anova

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
dataset = 'NEMOS'

# Variable
variable = 'mmse_adj'

# ROI
roi = 'Cingulate gyrus, Anterior'

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
# Load AAL atlas
# -----------------------
aal_path = os.path.join('..', '..', 'data', 'templates', 'template_AAL.mat')
aal = sio.loadmat(aal_path)
aal_names = [name.item() for name in aal['atlas']['name'].item()]
roi_idx = [i + 1 for i, name in enumerate(aal_names) if roi in str(name)]
area = aal['grid']['area'].item().flatten()
mask = np.isin(area, roi_idx).astype(int)
mask = mask == 1

# -----------------------
# Load apexp data and average in roi
# -----------------------
roi_avg = {
    pid: {'participant_id': pid}
    for pid in participants['participant_id']
}

for pid, apexp_file in apexp_files.items():

    # Load apexp data (1D, Nsources)
    fooofdata = sio.loadmat(apexp_file, squeeze_me=True, struct_as_record=False)
    apexp = fooofdata['apexp_imp']

    # Extract apexp in roi and average across positions
    apexp_roi = apexp[mask]
    roi_avg[pid] = np.nanmean(apexp_roi, axis=0)

# Dict to dataframe
roi_avg = pd.DataFrame(roi_avg.items(), columns=['participant_id', 'roi_avg'])

# Merge roi_avg with participants
results = participants.merge(roi_avg,on='participant_id',how='left')

# -----------------
# Linear model between roi_avg and 'variable'
# ------------------
if variable == 'mmse_adj':
    fig, ax = plt.subplots(figsize=(3, 2.5))

    for group, subset in results.groupby('diagnosis'):
        # Omit HC
        if group == 'HC':
            continue

        x = sm.add_constant(subset[[variable,'age']])
        y = subset['roi_avg']

        # Linear model for this group
        model = sm.OLS(y,x, missing='drop').fit()
        print(group)
        print(model.summary())

        xfit = np.linspace(subset[variable].min(), subset[variable].max(), 100)
        xpred = pd.DataFrame({'const':1, variable:xfit, 'age':subset['age'].mean()})
        yfit = model.predict(xpred)

        # # Pearson's r
        # x_ = subset['roi_avg']
        # y_ = subset[variable]
        # mask = np.isfinite(x_) & np.isfinite(y_)
        # res = pearsonr(x_[mask], y_[mask])
        # print(f"Pearson R: R = {res.statistic:.3f}, p = {res.pvalue:.4g}")

        # Scatter plot
        plt.scatter(
            subset[variable],
            subset['roi_avg'],
            color=group_colors[dataset].get(group, 'gray'),
            edgecolors='none',
            alpha=0.7,
            s = 40,
            label=group
        )

        # Linear fit plot
        plt.plot(xfit, yfit, color=group_colors[dataset].get(group, 'gray'),
                 linewidth=2, label='_nolegend_')

    plt.xlabel('MMSE', fontname='Roboto', fontsize=12)
    plt.ylabel('Aperiodic exponent', fontname='Roboto', fontsize=12)
    # plt.title(dataset, fontname='Roboto', fontsize=10)
    handles, labels = ax.get_legend_handles_labels()
    order = [1, 0]
    plt.legend([handles[idx] for idx in order], [labels[idx] for idx in order], frameon=True, loc='lower left')


    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#9d9d9c')
    ax.spines['bottom'].set_color('#9d9d9c')
    ax.tick_params(axis='both', colors='#9d9d9c')


# -----------------
# Differences between apexp and 'apoe'
# ------------------
if variable == 'apoe':

    apoe_status = ['E4-', 'E4+']
    fig, axes = plt.subplots(1,3, figsize=(4, 2.5), sharey='row')

    groups = list(group_colors[dataset].keys())

    spacing = 0.3
    positions = np.arange(len(apoe_status)) * spacing + 1

    # --------------------------------------------------
    # Prepare data for ANOVA
    # --------------------------------------------------

    anova_data = results.copy()

    # Binary code apoe status
    anova_data['APOE_group'] = np.where(anova_data['APOE'].astype(str).str.contains('4'),'E4+','E4-')

    # Remove missing values
    anova_data = anova_data.dropna(subset=['roi_avg', 'APOE_group', 'diagnosis'])

    # Make categorical variables
    anova_data['APOE_group'] = pd.Categorical(anova_data['APOE_group'],categories=apoe_status)
    anova_data['diagnosis'] = pd.Categorical(anova_data['diagnosis'],categories=groups)

    # --------------------------------------------------
    # Two-way ANOVA
    # --------------------------------------------------
    model = ols('roi_avg ~ C(APOE_group) * C(diagnosis)', data=anova_data).fit()
    anova_table = sm.stats.anova_lm(model, typ=2)
    print('\nTwo-way ANOVA')
    print(anova_table)


    for ax, group in zip(axes, groups):

        subset = results[results['diagnosis'] == group].copy()

        # Binary code apoe status
        subset['APOE_group'] = np.where(subset['APOE'].astype(str).str.contains('4'), 'E4+', 'E4-')
        box_data = [subset.loc[subset['APOE_group'] == apoe, 'roi_avg'] for apoe in apoe_status]
        print(subset['APOE_group'].value_counts().sort_index())

        # # T-test between E4- and E4+
        # t, p = stats.ttest_ind(box_data[0], box_data[1], equal_var=False)
        # print(f"ttest E4- vs E4+: t = {t:.3f}, p = {p:.4g}")


        # Boxplot
        bp = ax.boxplot(
            box_data,
            positions=positions,
            labels=apoe_status,
            widths=0.15,
            patch_artist=True,
            showfliers=False,
            boxprops=dict(facecolor='none', edgecolor='#5A5A5A', linewidth=1.5),
            medianprops=dict(color='#5A5A5A', linewidth=3),
            whiskerprops=dict(color='#5A5A5A', linewidth=1.5),
            capprops=dict(color='#5A5A5A', linewidth=1.5),
        )

        # Raw scattered data
        for i, apoe in enumerate(apoe_status):
            y = subset.loc[subset['APOE_group'] == apoe, 'roi_avg']
            # Jittered x positions
            x = np.random.normal(loc=positions[i], scale=0.05, size=len(y))
            ax.scatter(x, y,
                color=group_colors[dataset].get(group, 'gray'),
                edgecolors='none',
                alpha=0.4,
                s = 40,
                zorder=1,
            )

        ax.set_xmargin(-0.2)

        ax.title.set_text(group)

        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.spines['bottom'].set_visible(False)
        ax.spines['left'].set_color('#9d9d9c')
        ax.tick_params(axis='both', colors='#9d9d9c')

    fig.supylabel('Aperiodic exponent', fontname='Roboto', fontsize=12)
    fig.supxlabel('APOE status', fontname='Roboto', fontsize=12)
    # fig.suptitle(dataset)
    plt.tight_layout()

# -----------------
# Differences between apexp and sex
# ------------------
if variable == 'sex':

    sex_cat = ['f', 'm']
    fig, axes = plt.subplots(1,3, figsize=(4, 2.5), sharey='row')

    groups = list(group_colors[dataset].keys())

    spacing = 0.3
    positions = np.arange(len(sex_cat)) * spacing + 1

    for ax, group in zip(axes, groups):

        subset = results[results['diagnosis'] == group].copy()

        box_data = [subset.loc[subset['sex'] == s, 'roi_avg'] for s in sex_cat]
        print(subset['sex'].value_counts().sort_index())

        # T-test between E4- and E4+
        t, p = stats.ttest_ind(box_data[0], box_data[1], equal_var=False)
        print(f"ttest f vs m: t = {t:.3f}, p = {p:.4g}")


        # Boxplot
        bp = ax.boxplot(
            box_data,
            positions=positions,
            labels=sex_cat,
            widths=0.15,
            patch_artist=True,
            showfliers=False,
            boxprops=dict(facecolor='none', edgecolor='#5A5A5A', linewidth=1.5),
            medianprops=dict(color='#5A5A5A', linewidth=3),
            whiskerprops=dict(color='#5A5A5A', linewidth=1.5),
            capprops=dict(color='#5A5A5A', linewidth=1.5),
        )

        # Raw scattered data
        for i, s in enumerate(sex_cat):
            y = subset.loc[subset['sex'] == s, 'roi_avg']
            # Jittered x positions
            x = np.random.normal(loc=positions[i], scale=0.05, size=len(y))
            ax.scatter(x, y,
                color=group_colors[dataset].get(group, 'gray'),
                edgecolors='none',
                alpha=0.4,
                s = 40,
                zorder=1,
            )

        ax.set_xmargin(-0.2)

        ax.title.set_text(group)

        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.spines['bottom'].set_visible(False)
        ax.spines['left'].set_color('#9d9d9c')
        ax.tick_params(axis='both', colors='#9d9d9c')

    fig.supylabel('Aperiodic exponent', fontname='Roboto', fontsize=12)
    fig.supxlabel('Sex', fontname='Roboto', fontsize=12)
    # fig.suptitle(dataset)
    plt.tight_layout()

# Save figure
output_file = os.path.join(figs_folder, f'corr_apexp_{variable}_{dataset}_{roi}_20260918.svg')
plt.savefig(output_file, dpi=300, transparent=True, bbox_inches='tight')
plt.close()
print(f'Saved figure: {output_file}')