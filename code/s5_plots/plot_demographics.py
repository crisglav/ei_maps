# This scripts performs statistics on the dataset's demographics
#
# Cristina Gil Ávila, C3N, 17/09/2026

import os
import json
import numpy as np
import pandas as pd
from scipy import stats

from statsmodels.formula.api import ols
from statsmodels.stats.anova import anova_lm
from statsmodels.stats.multicomp import pairwise_tukeyhsd
from statsmodels.stats.proportion import proportions_chisquare
from statsmodels.stats.multitest import multipletests
from itertools import combinations

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
    groups = ['FH','HC']
    plot_groups = True

# Variables
variables = ['n','age','sex','mmse_adj','edu_years','APOE']

# Config file
config_file = os.path.join('..', 'config_megtusalen.json')
config = json.load(open(config_file))

# Participants file
participants_path = config['path']['participants']

# -----------------------
# Load participants metadata
# -----------------------
participants = pd.read_excel(participants_path)

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


# -----------------------
# Test differences between groups
# -----------------------
for var in ['age','mmse_adj','edu_years']:
    print(var)

    if dataset == 'FAM':
        fh = participants.loc[participants['diagnosis'] == 'FH', var].dropna()
        hc = participants.loc[participants['diagnosis'] == 'HC', var].dropna()
        tstat, pval = stats.ttest_ind(hc, fh, equal_var=False, alternative='two-sided')
        print(f't = {tstat:.2f}, p = {pval:.7f}')

    else:
        formula = f'{var} ~ C(diagnosis)'
        model = ols(formula, data=participants).fit()
        table = anova_lm(model, typ=2)
        fstat = table.loc['C(diagnosis)', 'F']
        pval = table.loc['C(diagnosis)', 'PR(>F)']
        print(f'F = {fstat:.2f}, p = {pval:.7f}')

        if pval < 0.05:
            print("ANOVA significant")

            data = participants[[var, 'diagnosis']].dropna()
            tukey = pairwise_tukeyhsd(
                endog=data[var],
                groups=data['diagnosis'],
                alpha=0.05
            )
            print(tukey)


# -----------------------
# Chi-square tests for sex and APOE
# -----------------------
for variable in ['sex', 'APOE']:

    count = []
    nobs = []

    for group in groups:

        if variable == 'sex':
            n = np.sum((participants['sex'] == 'f') &(participants['diagnosis'] == group))

        elif variable == 'APOE':
            n = np.sum(participants['APOE'].astype(str).str.contains('4', na=False) & (participants['diagnosis'] == group))

        total = np.sum(participants['diagnosis'] == group)

        count.append(n)
        nobs.append(total)

    # Overall Chi-square test
    chi2, pval, table = proportions_chisquare(count=count,nobs=nobs)

    print(f'\n{variable}')
    print(f'Chi2 = {chi2:.1f}, p = {pval:.3e}')

    # Pairwise tests if significant
    if pval < 0.05:

        pairwise_pvals = []
        pairwise_names = []

        for i, j in combinations(range(len(groups)), 2):

            table = np.array([
                [count[i], nobs[i] - count[i]],
                [count[j], nobs[j] - count[j]]
            ])

            chi2_pair, p_pair, _, _ = stats.chi2_contingency(table)

            pairwise_pvals.append(p_pair)
            pairwise_names.append(f'{groups[i]} vs {groups[j]}')

        # FDR correction
        _, pvals_fdr, _, _ = multipletests(pairwise_pvals,method='fdr_bh')

        print('Pairwise tests:')
        for name, p_raw, p_fdr in zip(pairwise_names, pairwise_pvals, pvals_fdr):
            print(f'{name}: 'f'χ² = {chi2_pair:.1f}, 'f'p = {p_raw:.5f}, 'f'p-FDR = {p_fdr:.5f}')