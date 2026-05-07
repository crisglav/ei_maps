import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from scipy.stats import ttest_1samp

import pingouin as pg
from scipy.stats import chi2_contingency
from scipy.stats import f_oneway

np.random.seed(42)

# Path to results csv
results_file = os.path.join('..', 'results', 'corr_apexp_receptors_wa_FAM_PYTHON_NEWSCRIPT.csv')
results = pd.read_csv(results_file)

# Load participants to divide by group
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Create column group merged
participants["group_merged"] = participants["group"].replace({
    "MCIa": "MCI",
    "MCIm": "MCI",
    "CONV": "AD"
})

# List receptors
receptors = ['mGluR5','NMDA','GABA_flumazenil','GABA_a5','VAChT','ACh_a4b2','ACh_M1']

participants = participants.merge(
    results,
    on="participant_id",
    how="inner"
)

# Q2. Is the aperiodic exponent in healthy individuals (FAMILIARES PROJECT) correlated with NT maps?
fam = participants[participants["participant_id"].astype(str).str.startswith("FAM")].copy()

# Two-sided t-tests assesing whether correlation coefficients are different from zero for each receptor.
results = []
for receptor in receptors:
    r_col = f"corr_{receptor}"
    vals = fam[r_col]

    t, p = ttest_1samp(vals, 0)

    results.append({
        "receptor": receptor,
        "n": len(vals),
        "mean_r": vals.mean(),
        "t": t,
        "p": p
    })

results_df = pd.DataFrame(results)
print("\nSummary")
print(results_df)

# Repeated measures ANOVA testing whether correlation coefficients are different between receptor types
r_cols = [f"corr_{r}" for r in receptors]
fam_long = fam.melt(
    id_vars=["participant_id"],
    value_vars=r_cols,
    var_name="receptor",
    value_name="r_value"
)

fam_long["receptor"] = fam_long["receptor"].str.replace("corr_", "", regex=False)

rm_anova = pg.rm_anova(
    data=fam_long,
    dv="r_value",
    within="receptor",
    subject="participant_id",
    detailed=True,
    effsize="np2"
)

print(rm_anova.to_string())

# Post-hoc tests
posthoc = pg.pairwise_ttests(
    data=fam_long,
    dv="r_value",
    within="receptor",
    subject="participant_id",
    padjust="bonf"
)

print(posthoc.to_string())




# RQ3: Differences between groups
groups = ['MCIneg','MCI','AD']

count_results = []

for receptor in receptors:
    pval_col = f"pval_{receptor}"

    # significant yes/no
    participants["sig"] = participants[pval_col] < 0.05

    table = pd.crosstab(
        participants["group_merged"],
        participants["sig"]
    ).reindex(groups, fill_value=0)

    chi2, p, dof, expected = chi2_contingency(table)

    count_results.append({
        "receptor": receptor,
        "chi2": chi2,
        "p": p
    })

    print(f"\n{receptor}")
    print(table)
    print(f"Chi2 = {chi2:.3f}, p = {p:.4f}")

count_df = pd.DataFrame(count_results)
print("\nSummary")
print(count_df)