import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import statsmodels.api as sm

np.random.seed(42)

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

participants = pd.read_excel(os.path.join('..', 'data', 'participants_20260814.xlsx'))

datasets = {
    "NEMOS": os.path.join('..', 'results', 'fooof_global', 'NEMOS_fooof_subj_results.csv'),
    "UMEC": os.path.join('..', 'results', 'fooof_global', 'UMEC_fooof_subj_results.csv'),
}

for dataset_name, results_path in datasets.items():

    print(f"\n{'=' * 60}\n{dataset_name}\n{'=' * 60}")

    results = pd.read_csv(results_path)
    participants_this = participants[participants["participant_id"].astype(str).str.startswith(dataset_name)].copy()
    # Do not include healthy
    # participants_this = participants_this[participants_this['diagnosis'] != 'HC'].copy()

    data = results.merge(
        participants_this[['participant_id', 'diagnosis', 'edu_years']],
        on='participant_id',
        how='inner'
    )[['participant_id', 'diagnosis', 'apexp', 'edu_years']].dropna()

    plt.figure(figsize=(6, 5))


    X = sm.add_constant(data['apexp'])
    y = data['edu_years']
    model = sm.OLS(y, X).fit()

    print(model.summary())

    xfit = np.linspace(data['apexp'].min(), data['apexp'].max(), 100)
    yfit = model.predict(sm.add_constant(xfit))



    for diagnosis, subset in data.groupby('diagnosis'):
        plt.scatter(
            subset['apexp'],
            subset['edu_years'],
            color=group_colors[dataset_name].get(diagnosis, 'gray'),
            alpha=0.7,
            s=40,
            label=diagnosis
        )

    plt.plot(xfit, yfit, color='black', linewidth=2, label='Linear fit')
    plt.xlabel('Aperiodic exponent')
    plt.ylabel('Education years')
    plt.title(dataset_name)
    plt.text(0.75, 0.15, f'R² = {model.rsquared:.3f}\np = {model.pvalues["apexp"]:.3g}', transform=plt.gca().transAxes, va='top')
    plt.legend(title='Diagnosis', frameon=False, loc='lower left')
    plt.tight_layout()
    plt.show()