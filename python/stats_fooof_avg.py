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
results_path = os.path.join('..','results','fooof_global', 'fooof_subj_results.csv')
results = pd.read_csv(results_path)

# Load participants data for age
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

results = results.merge(participants[['participant_id','age','diagnosis']], on='participant_id', how='inner')

# Statistical test: differences in aperiodic exponent across groups
model = ols('apexp ~ C(group) + age', data=results).fit()
ancova_table = sm.stats.anova_lm(model, typ=2)
print(ancova_table)

tukey = pairwise_tukeyhsd(
    endog=results["apexp"],
    groups=results["group"],
    alpha=0.05
)
print(tukey)

# Statistical test: differences in aperiodic offset across groups
model = ols('offset ~ C(group) + age', data=results).fit()
ancova_table = sm.stats.anova_lm(model, typ=2)
print(ancova_table)

tukey = pairwise_tukeyhsd(
    endog=results["offset"],
    groups=results["group"],
    alpha=0.05
)
print(tukey)


# Plotting: aperiodic exponent per group
group_colors = {
    "MCIneg":  "#1B5E20",  # dark green
    "SCDneg":  "#43A047",  # green
    "SCD":     "#FDD835",  # yellow
    "MCI":     "#FB8C00",  # red-orange
    "AD":      "#8B0000",  # dark red
}
# group_colors = {
#     "HC":  "#43A047",  # green
#     "SCD":     "#FDD835",  # yellow
#     "MCI":     "#FB8C00",  # red-orange
#     "AD":      "#8B0000",  # dark red
# }

plt.figure(figsize=(8, 6))
for i, (group, color) in enumerate(group_colors.items()):

    subset = results[results["group"] == group]

    x = np.random.normal(loc=i + 1,scale=0.05,size=len(subset))
    plt.scatter(x,subset["apexp"],color=color, alpha=0.7,label=group)

    mean_apexp = subset["apexp"].mean()
    plt.scatter(i + 1,mean_apexp,color="black",marker="_", s=500,linewidths=3,zorder=10)

plt.xticks(range(1, len(group_colors) + 1),group_colors.keys(),rotation=45)
plt.ylabel("Aperiodic exponent")
plt.xlabel("Group")
plt.title("Distribution of aperiodic exponents by group")
plt.tight_layout()
plt.show()

# Aperiodic offset
plt.figure(figsize=(8, 6))
for i, (group, color) in enumerate(group_colors.items()):

    subset = results[results["group"] == group]

    x = np.random.normal(loc=i + 1,scale=0.05,size=len(subset))
    plt.scatter(x,subset["offset"],color=color, alpha=0.7,label=group)

    mean_offset = subset["offset"].mean()
    plt.scatter(i + 1,mean_offset,color="black",marker="_", s=500,linewidths=3,zorder=10)

plt.xticks(range(1, len(group_colors) + 1),group_colors.keys(),rotation=45)
plt.ylabel("Aperiodic offset")
plt.xlabel("Group")
plt.title("Distribution of aperiodic offsets by group")
plt.tight_layout()
plt.show()

# Plotting average power spectra per group
with open(os.path.join('..','results','fooof_global',"fm_group.pkl"), "rb") as f:
    fm_group = pickle.load(f)

for group, color in group_colors.items():

    fm = fm_group[group]

    plt.plot(fm.freqs, fm.power_spectrum, color=color, alpha=0.6, linewidth=2, label = group)
    plt.plot(fm.freqs, fm._ap_fit, color=color, linestyle="--", linewidth=2)

plt.xscale('log')
plt.xlabel("Frequency (Hz)")
plt.ylabel("Log Power")
plt.title("Group-average spectra and aperiodic fits")
plt.legend()
plt.tight_layout()

out_file = os.path.join('..','figs','fooof_global', "PSDs 5 groups.svg")

plt.savefig(
    out_file,
    dpi=300,
    bbox_inches="tight",
    transparent=True
)
