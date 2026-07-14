import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import statsmodels.api as sm

np.random.seed(42)

group_colors = {
        "MCIstable": "#FB8C00",
        "MCIconv": "#8B0000"
}

participants = pd.read_excel(os.path.join('..', 'data', 'participants_cog.xlsx'))

dataset = os.path.join('..', 'results', 'fooof_global', 'NEMOS_CONV_fooof_subj_results.csv')
results = pd.read_csv(dataset)

data = results.merge(
    participants[['participant_id', 'age', 'conversion_time','converter','mmse_adj']],
    on='participant_id',
    how='inner'
)[['participant_id', 'age', 'group', 'apexp', 'conversion_time','converter', 'mmse_adj']].dropna()

data = data[data['converter'] == 1].copy()

plt.figure(figsize=(6, 5))


X = sm.add_constant(data[['apexp', 'mmse_adj']])
y = data['conversion_time']
model = sm.OLS(y, X).fit()

print(model.summary())

xfit = np.linspace(data['apexp'].min(), data['apexp'].max(), 100)
Xfit = pd.DataFrame({
    'const': 1,
    'apexp': xfit,
    'mmse_adj': data['mmse_adj'].mean()
})

yfit = model.predict(Xfit)

plt.scatter(
    data['apexp'],
    data['conversion_time'],
    color='#FB8C00',
    alpha=0.7)

plt.plot(xfit, yfit, color='black', linewidth=2, label='Linear fit')
plt.xlabel('Aperiodic exponent')
plt.ylabel('Time to conversion to AD (months)')
plt.title('NEMOS converters')
plt.text(
    0.8,
    0.95,
    f'R² = {model.rsquared:.3f}\n'
    f'p apexp = {model.pvalues["apexp"]:.3g}\n'
    f'p mmse = {model.pvalues["mmse_adj"]:.3g}',
    transform=plt.gca().transAxes,
    va='top'
)
plt.tight_layout()
plt.show()