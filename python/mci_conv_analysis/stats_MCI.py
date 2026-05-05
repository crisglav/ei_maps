import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from scipy.stats import chi2_contingency

np.random.seed(42)

# Path to results csv
results_file = os.path.join('../..', 'results', 'MCI_corr_apexp_receptors_wa.csv')
results = pd.read_csv(results_file)

# Load participants to divide by group
participants_path = os.path.join('../..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# NEMOS ONLY
participants = participants[participants["participant_id"].astype(str).str.startswith("NEMOS")]

# Create column group merged
participants["group_merged"] = participants["group"].replace({
    "MCIa": "MCI_stable",
    "MCIm": "MCI_stable",
    "CONV": "MCI_conv",
    "MCIneg": "HC",
})

groups = ['HC', 'MCI_stable', 'MCI_conv']

# List receptors
receptors = ['mGluR5','NMDA','GABA_flumazenil','GABA_a5','VAChT','ACh_a4b2','ACh_M1']

participants = participants.merge(
    results,
    on="participant_id",
    how="inner"
)

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