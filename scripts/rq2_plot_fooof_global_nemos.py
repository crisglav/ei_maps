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
participants = participants[mask].copy()

results = results.merge(participants[['participant_id','age','diagnosis']], on='participant_id', how='inner')

# Plotting: aperiodic exponent per group
group_colors = {
    "HC":      "#43A047",  # green
    "MCI":     "#FB8C00",  # red-orange
    "AD":      "#8B0000",  # dark red
}

# Plotting average power spectra per group
with open(os.path.join('..','results','fooof_global',"NEMOS_fm_group.pkl"), "rb") as f:
    fm_group = pickle.load(f)

for group, color in group_colors.items():

    fm = fm_group[group]

    plt.plot(np.log(fm.freqs), fm.power_spectrum, color=color, alpha= 0.6, linewidth=2, label = group)
    plt.plot(np.log(fm.freqs), fm._ap_fit, color=color, linestyle="--", linewidth=2)

# plt.xscale('log')
plt.xlabel("log(frequency)")
plt.ylabel("log(power)")
plt.title("Group-average spectra and aperiodic fits")
plt.legend()
plt.tight_layout()

ax = plt.gca()
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.yaxis.set_ticks_position('left')
ax.xaxis.set_ticks_position('bottom')

out_file = os.path.join('..','figs','fooof_global', "rq2_fooof_global_NEMOS.svg")

plt.savefig(
    out_file,
    dpi=300,
    bbox_inches="tight",
    transparent=True
)
