# This scripts performs statistics on the correlations'distribtions (betweeen the aperiodic exponent and 6 neurotransmitter maps)
#
# Cristina Gil Ávila, C3N, 17/09/2026

import os
import json
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats
import statsmodels.api as sm
from statsmodels.formula.api import ols
from statsmodels.stats.proportion import proportions_chisquare
from statsmodels.stats.multicomp import pairwise_tukeyhsd
from statsmodels.stats.multitest import multipletests
from traits.trait_types import false
from itertools import combinations

np.random.seed(42)

# -----------------------
# Config
# -----------------------
# Dataset
dataset = 'UMEC'

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
# fname = os.path.join('..', '..', 'results', f'corr_apexp_receptors_{dataset}_20260831_results.csv')
# results.to_csv(fname, sep = '\t')

# -----------------------
# Percentage of significant correlations
# -----------------------
if plot_groups:

    for i, receptor in enumerate(receptor_colors):
        corr_col = f'corr_{receptor}'
        pval_col = f'pval_{receptor}'

        for group in groups:
            subset = results[results['diagnosis'] == group]

            y = subset[corr_col]
            pvals = subset[pval_col]
            significant = pvals < 0.05
            non_significant = pvals >= 0.05

            color = receptor_colors.get(receptor, 'black')

            persig = (sum((significant)) / len(significant)) * 100
            pernonsig = (sum(non_significant) / len(non_significant)) * 100
            medianR = np.median(y)
            iqrR = stats.iqr(y)

            print(f'{receptor} | {group} : significant {persig:.2f}%, ({pernonsig:.2f})%, medianR {medianR:.2f} ({iqrR:.2f})')

else:
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

# -----------------------
# Test number of significant correlations - chi square
# -----------------------
pvalchi = []
for i, receptor in enumerate(receptor_colors):
    pval_col = f'pval_{receptor}'

    counts = []
    nobs = []

    for group in groups:

        nsig = np.sum((results[pval_col] < 0.05) & (results['diagnosis'] == group))
        ntotal = np.sum((results['diagnosis'] == group))

        counts.append(nsig)
        nobs.append(ntotal)

    # Chi-square test
    chi2, pval, table = proportions_chisquare(count=counts,nobs=nobs)
    pvalchi.append(pval)

    print(receptor)
    print(pval)

    if pval < 0.05:
        print("Chi square significant")
        posthoc_results = []

        third_combination = list(combinations(range(len(groups)), 2))[2]

        for i, j in combinations(range(len(groups)), 2):

            count_pair = np.array([counts[i], counts[j]])
            nobs_pair = np.array([nobs[i], nobs[j]])

            stat, pval, _ = proportions_chisquare(count_pair,nobs_pair)

            posthoc_results.append({
                'receptor': receptor,
                'group1': groups[i],
                'group2': groups[j],
                'per1':(count_pair[0]/nobs_pair[0])*100,
                'per2': (count_pair[1] / nobs_pair[1]) * 100,
                'chi2': stat,
                'pval': pval
            })

        print(pd.DataFrame(posthoc_results))

# Correct pval for multiple comparisons with fdr
reject, pvals_fdr, _, _ = multipletests(pvalchi, alpha=0.05, method='fdr_bh')
print(pvals_fdr)




# -----------------------
# Test differences in mean distributions (R) - anova
# -----------------------
anovapval = []
for i, receptor in enumerate(receptor_colors):
    corr_col = f'corr_{receptor}'

    formula = f'{corr_col} ~ C(diagnosis)'
    model = ols(formula, data=results).fit()
    table = sm.stats.anova_lm(model, typ=2)
    print(receptor)
    print(table)
    anovapval.append(table.loc['C(diagnosis)', 'PR(>F)'])

    if table.loc['C(diagnosis)', 'PR(>F)'] < 0.05:
        print("ANOVA significant")

        tukey = pairwise_tukeyhsd(
            endog=results[corr_col],
            groups=results['diagnosis'],
            alpha=0.05
        )
        print(tukey)

# Correct anova pval for multiple comparisons with fdr
reject, pvals_fdr, _, _ = multipletests(anovapval,alpha=0.05,method='fdr_bh')
print(pvals_fdr)