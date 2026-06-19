import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import pickle
import statsmodels.api as sm
from statsmodels.formula.api import ols
from statsmodels.stats.multicomp import pairwise_tukeyhsd

np.random.seed(42)

# Load apexp data
results_path = os.path.join('..','results','fooof_global', 'NEMOS_fooof_subj_results.csv')
results = pd.read_csv(results_path)

# Load participants data for age
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

mask = participants["participant_id"].astype(str).str.startswith("NEMOS")
nemos = participants[mask].copy()
results_nemos = results.merge(nemos[['participant_id','age','diagnosis']], on='participant_id', how='inner')

# Statistical test: differences in aperiodic exponent across groups
model = ols('apexp ~ C(group) + age', data=results_nemos).fit()
ancova_table = sm.stats.anova_lm(model, typ=2)
print(ancova_table)

tukey = pairwise_tukeyhsd(
    endog=results_nemos["apexp"],
    groups=results_nemos["group"],
    alpha=0.05
)
print(tukey)

# Statistical test: differences in aperiodic offset across groups
model = ols('offset ~ C(group) + age', data=results_nemos).fit()
ancova_table = sm.stats.anova_lm(model, typ=2)
print(ancova_table)

tukey = pairwise_tukeyhsd(
    endog=results_nemos["offset"],
    groups=results_nemos["group"],
    alpha=0.05
)
print(tukey)


# Load apexp data
results_path = os.path.join('..','results','fooof_global', 'UMEC_fooof_subj_results.csv')
results = pd.read_csv(results_path)

mask = participants["participant_id"].astype(str).str.startswith("UMEC")
umec = participants[mask].copy()
results_umec = results.merge(umec[['participant_id','age','diagnosis']], on='participant_id', how='inner')

# Statistical test: differences in aperiodic exponent across groups
model = ols('apexp ~ C(group) + age', data=results_umec).fit()
ancova_table = sm.stats.anova_lm(model, typ=2)
print(ancova_table)

tukey = pairwise_tukeyhsd(
    endog=results_umec["apexp"],
    groups=results_umec["group"],
    alpha=0.05
)
print(tukey)

# Statistical test: differences in aperiodic offset across groups
model = ols('offset ~ C(group) + age', data=results_umec).fit()
ancova_table = sm.stats.anova_lm(model, typ=2)
print(ancova_table)

tukey = pairwise_tukeyhsd(
    endog=results_umec["offset"],
    groups=results_umec["group"],
    alpha=0.05
)
print(tukey)
