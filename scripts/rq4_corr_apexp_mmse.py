import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import statsmodels.api as sm


np.random.seed(42)
############## NEMOS ###############
# Load apexp data
results_path = os.path.join('..','results','fooof_global', 'NEMOS_fooof_subj_results.csv')
results = pd.read_csv(results_path)

# Load participants data for age
participants_path = os.path.join('..', 'data', 'participants_cog.xlsx')
participants = pd.read_excel(participants_path)

mask = participants["participant_id"].astype(str).str.startswith("NEMOS")
nemos = participants[mask].copy()
results_nemos = results.merge(nemos[['participant_id','age','diagnosis','mmse_adj']], on='participant_id', how='inner')

# Remove missing values
data = results_nemos[['participant_id','age','diagnosis','apexp', 'mmse_adj']]
data = data.dropna()

x = sm.add_constant(data['mmse_adj'])  # intercept
y = data['apexp']

model = sm.OLS(y, x).fit()

print(model.summary())

# Regression line
xfit = np.linspace(
    data['mmse_adj'].min(),
    data['mmse_adj'].max(),
    100
)
yfit = model.predict(sm.add_constant(xfit))

# Plot
group_colors = {
    # "HC":  "#43A047",  # green
    "MCI": "#FB8C00",  # orange
    "AD":  "#8B0000",  # dark red
}

plt.figure(figsize=(6, 5))

for diagnosis, subset in data.groupby('diagnosis'):
    plt.scatter(
        subset['mmse_adj'],
        subset['apexp'],
        label=diagnosis,
        color=group_colors.get(diagnosis, 'gray'),
        alpha=0.7
    )

plt.plot(
    xfit,
    yfit,
    color='black',
    linewidth=2,
    label='Linear fit'
)

plt.xlabel('Adjusted MMSE')
plt.ylabel('Aperiodic exponent')

plt.text(
    0.05,
    0.95,
    f'R² = {model.rsquared:.3f}\np = {model.pvalues["mmse_adj"]:.3g}',
    transform=plt.gca().transAxes,
    va='top'
)

plt.legend(title='Diagnosis')
plt.tight_layout()
plt.show()

