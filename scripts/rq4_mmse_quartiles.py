import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.stats as stats

np.random.seed(42)

# -----------------------
# Colors
# -----------------------

quartile_colors = {
    "Q1": "#D9D9D9",
    "Q2": "#BDBDBD",
    "Q3": "#969696",
    "Q4": "#636363",
}

# -----------------------
# Load participant metadata
# -----------------------

participants_path = os.path.join(
    '..',
    'data',
    'participants_cog.xlsx'
)

participants = pd.read_excel(participants_path)

# -----------------------
# Datasets
# -----------------------

datasets = {
    "NEMOS": os.path.join(
        '..',
        'results',
        'fooof_global',
        'NEMOS_fooof_subj_results.csv'
    ),
    "UMEC": os.path.join(
        '..',
        'results',
        'fooof_global',
        'UMEC_fooof_subj_results.csv'
    ),
}

# -----------------------
# Loop over datasets
# -----------------------

for dataset_name, results_path in datasets.items():

    print("\n" + "=" * 60)
    print(dataset_name)
    print("=" * 60)

    # Load results
    results = pd.read_csv(results_path)

    # Select participants
    mask = (
        participants["participant_id"]
        .astype(str)
        .str
        .startswith(dataset_name)
    )

    participants_this = participants.loc[mask].copy()

    # Merge data
    data = results.merge(
        participants_this[
            [
                'participant_id',
                'age',
                'diagnosis',
                'mmse_adj'
            ]
        ],
        on='participant_id',
        how='inner'
    )

    data = data[
        [
            'participant_id',
            'age',
            'diagnosis',
            'apexp',
            'mmse_adj'
        ]
    ].dropna()

    # -----------------------
    # Create MMSE quartiles
    # -----------------------

    data['mmse_quartile'] = pd.qcut(
        data['mmse_adj'],
        q=4,
        labels=['Q1', 'Q2', 'Q3', 'Q4']
    )

    print(data['mmse_quartile'].value_counts().sort_index())

    # -----------------------
    # ANOVA across quartiles
    # -----------------------

    quartile_data = [
        data.loc[data['mmse_quartile'] == q, 'apexp']
        for q in ['Q1', 'Q2', 'Q3', 'Q4']
    ]

    f_stat, p_val = stats.f_oneway(*quartile_data)

    print(f"ANOVA apexp ~ MMSE quartile")
    print(f"F = {f_stat:.3f}, p = {p_val:.4g}")

    # -----------------------
    # Boxplot
    # -----------------------

    plt.figure(figsize=(6, 5))

    box_data = [
        data.loc[data['mmse_quartile'] == q, 'apexp']
        for q in ['Q1', 'Q2', 'Q3', 'Q4']
    ]

    bp = plt.boxplot(
        box_data,
        labels=['Q1', 'Q2', 'Q3', 'Q4'],
        patch_artist=True,
        showfliers=False
    )

    for patch, q in zip(bp['boxes'], ['Q1', 'Q2', 'Q3', 'Q4']):
        patch.set_facecolor(quartile_colors[q])
        patch.set_alpha(0.7)

    # Add individual points
    for i, q in enumerate(['Q1', 'Q2', 'Q3', 'Q4'], start=1):

        y = data.loc[data['mmse_quartile'] == q, 'apexp']

        x = np.random.normal(
            loc=i,
            scale=0.05,
            size=len(y)
        )

        plt.scatter(
            x,
            y,
            color='black',
            alpha=0.5,
            s=25
        )

    plt.xlabel('MMSE adjusted quartile')
    plt.ylabel('Aperiodic exponent')
    plt.title(dataset_name)

    plt.text(
        0.05,
        0.95,
        f'ANOVA p = {p_val:.3g}',
        transform=plt.gca().transAxes,
        va='top'
    )

    plt.tight_layout()
    plt.show()