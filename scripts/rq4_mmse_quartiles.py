import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.stats as stats

np.random.seed(42)

quartile_colors = {"Q1": "#D9D9D9", "Q2": "#BDBDBD", "Q3": "#969696", "Q4": "#636363"}
quartiles = ["Q1", "Q2", "Q3", "Q4"]

participants = pd.read_excel(os.path.join('..', 'data', 'participants_cog.xlsx'))

datasets = {
    "NEMOS": os.path.join('..', 'results', 'fooof_global', 'NEMOS_fooof_subj_results.csv'),
    "UMEC": os.path.join('..', 'results', 'fooof_global', 'UMEC_fooof_subj_results.csv'),
}

for dataset_name, results_path in datasets.items():

    print(f"\n{'=' * 60}\n{dataset_name}\n{'=' * 60}")

    results = pd.read_csv(results_path)
    participants_this = participants[participants["participant_id"].astype(str).str.startswith(dataset_name)]

    data = results.merge(
        participants_this[['participant_id', 'age', 'diagnosis', 'mmse_adj']],
        on='participant_id',
        how='inner'
    )[['participant_id', 'age', 'diagnosis', 'apexp', 'mmse_adj']].dropna()

    data = data[data['diagnosis'] != 'HC'].copy()

    data['mmse_quartile'] = pd.qcut(
        data['mmse_adj'].rank(method='first'),
        q=4,
        labels=quartiles
    )

    print(data['mmse_quartile'].value_counts().sort_index())
    print(data.groupby('mmse_quartile')['mmse_adj'].agg(['min', 'max', 'count']))

    box_data = [data.loc[data['mmse_quartile'] == q, 'apexp'] for q in quartiles]
    f_stat, p_val = stats.f_oneway(*box_data)

    print(f"ANOVA apexp ~ MMSE quartile: F = {f_stat:.3f}, p = {p_val:.4g}")

    plt.figure(figsize=(6, 5))

    bp = plt.boxplot(box_data, labels=quartiles, patch_artist=True, showfliers=False)

    for patch, q in zip(bp['boxes'], quartiles):
        patch.set_facecolor(quartile_colors[q])
        patch.set_alpha(0.7)

    for i, q in enumerate(quartiles, start=1):
        y = data.loc[data['mmse_quartile'] == q, 'apexp']
        x = np.random.normal(i, 0.05, len(y))
        plt.scatter(x, y, color='black', alpha=0.5, s=25)

    plt.xlabel('Adjusted MMSE quartile')
    plt.ylabel('Aperiodic exponent')
    plt.title(dataset_name)
    plt.text(0.05, 0.95, f'ANOVA p = {p_val:.3g}', transform=plt.gca().transAxes, va='top')
    plt.tight_layout()
    plt.show()