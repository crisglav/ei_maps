import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.stats as stats

np.random.seed(42)

participants = pd.read_excel(os.path.join('..', 'data', 'participants_20260814.xlsx'))

datasets = {
    "NEMOS": os.path.join('..', 'results', 'fooof_global', 'NEMOS_fooof_subj_results.csv'),
    "UMEC": os.path.join('..', 'results', 'fooof_global', 'UMEC_fooof_subj_results.csv'),
}

for dataset_name, results_path in datasets.items():

    print(f"\n{'=' * 60}\n{dataset_name}\n{'=' * 60}")

    results = pd.read_csv(results_path)
    participants_this = participants[participants["participant_id"].astype(str).str.startswith(dataset_name)]

    data = results.merge(
        participants_this[['participant_id', 'age', 'diagnosis', 'APOE']],
        on='participant_id',
        how='inner'
    )[['participant_id', 'age', 'diagnosis', 'apexp', 'APOE']].dropna()

    data['APOE_group'] = np.where(data['APOE'].astype(str).str.contains('4'), 'E4+', 'E4-')

    groups = ['E4-', 'E4+']
    box_data = [data.loc[data['APOE_group'] == g, 'apexp'] for g in groups]

    t, p = stats.ttest_ind(box_data[0], box_data[1], equal_var=False)

    print(data['APOE_group'].value_counts().sort_index())
    print(f"Welch t-test E4- vs E4+: t = {t:.3f}, p = {p:.4g}")

    plt.figure(figsize=(5, 5))
    bp = plt.boxplot(box_data, labels=groups, patch_artist=True, showfliers=False)

    for box, color in zip(bp['boxes'], ['#BDBDBD', '#FB8C00']):
        box.set_facecolor(color)
        box.set_alpha(0.7)

    for i, g in enumerate(groups, start=1):
        y = data.loc[data['APOE_group'] == g, 'apexp']
        x = np.random.normal(i, 0.05, len(y))
        plt.scatter(x, y, color='black', alpha=0.5, s=25)

    plt.xlabel('APOE group')
    plt.ylabel('Aperiodic exponent')
    plt.title(dataset_name)
    plt.text(0.05, 0.95, f'p = {p:.3g}', transform=plt.gca().transAxes, va='top')
    plt.tight_layout()
    plt.show()