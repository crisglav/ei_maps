import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from neuromaps import resampling, images
from neuromaps.plotting import plot_surf_template

from nilearn.image import mean_img, smooth_img
from nilearn import datasets, surface, plotting


# Path to project root
project_root = r'C:\Users\Cristina\megtusalen'

# Figures folder
figs_folder = os.path.join('..', 'figs')

# Load participants file
participants_path = os.path.join('..', 'data', 'participants_real.xlsx')
participants = pd.read_excel(participants_path)

# Filter healthy participants
groups = ['FHpos', 'FHneg', 'SCDneg', 'MCIneg']
healthy = participants[participants['group'].isin(groups)].copy()

# List all the files in the apexp L1 folder
apexp_folder = os.path.join(project_root, 'L1', 'data', 'sources', 'apexp')

apexp_files = [
    f for f in os.listdir(apexp_folder)
    if f.endswith(".nii") or f.endswith(".nii.gz")
]

# Keep only healthy participants in the apexp files
healthy_ids = set(healthy['participant_id'])

apexp_files = [
    f for f in apexp_files
    if f.split("_")[0] in healthy_ids
]

# Map participant_id -> group
id_to_group = healthy.set_index('participant_id')['group'].to_dict()

group_files = {g: [] for g in groups}

for f in apexp_files:
    pid = f.split("_")[0]

    if pid in id_to_group:
        group = id_to_group[pid]
        group_files[group].append(os.path.join(apexp_folder, f))


fsavg = datasets.fetch_surf_fsaverage(mesh='fsaverage5')

for group, files in group_files.items():

    # Group average of apexp
    group_avg_img = mean_img(files, copy_header=True)

    # Add smoothing for visualization 5 mm
    group_avg_img = smooth_img(group_avg_img, fwhm=5)

    # Resample to surface
    apexp_resampled, _ = resampling.resample_images(
        src=group_avg_img,
        trg=group_avg_img,
        src_space='MNI152',
        trg_space='MNI152',
        resampling='transform_to_alt',
        alt_spec=('fsaverage', '10k')
    )

    # Plot
    plot_surf_template(
        apexp_resampled,
        template='fsaverage',
        density='10k',
        surf='inflated',
        mask_medial=True,
        colorbar=False,
        vmin=0,
        vmax=1,
    )

    plt.suptitle(group, fontsize=16, y=0.9)
    plt.savefig(
        os.path.join(figs_folder, f"apexp_dist_{group}.png"),
        dpi=300,
        transparent=True,
        bbox_inches='tight',
        pad_inches=0
    )
    plt.close()

    ##############################################################################################


    # # Sample onto left and right hemisphere surfaces
    # texture_l = surface.vol_to_surf(
    #     group_avg_img,
    #     fsavg.pial_left,
    #     inner_mesh=fsavg.white_left,
    #     interpolation='linear',
    #     n_samples=20
    # )
    #
    # texture_r = surface.vol_to_surf(
    #     group_avg_img,
    #     fsavg.pial_right,
    #     inner_mesh=fsavg.white_right,
    #     interpolation='linear',
    #     n_samples=20
    # )
    #
    # fig = plt.figure(figsize=(12, 8))
    #
    # plotting.plot_surf_stat_map(
    #     fsavg.pial_left, texture_l,
    #     hemi='left', view='lateral',
    #     figure=fig,
    #     darkness=0.9,
    #     cmap='plasma',
    #     colorbar=False,
    #     axes=fig.add_subplot(2, 2, 1, projection='3d')
    # )
    #
    # plotting.plot_surf_stat_map(
    #     fsavg.infl_right, texture_r,
    #     hemi='right', view='lateral',
    #     figure=fig,
    #     axes=fig.add_subplot(2, 2, 2, projection='3d')
    # )
    #
    # plotting.plot_surf_stat_map(
    #     fsavg.infl_left, texture_l,
    #     hemi='left', view='medial',
    #     figure=fig,
    #     axes=fig.add_subplot(2, 2, 3, projection='3d')
    # )
    #
    # plotting.plot_surf_stat_map(
    #     fsavg.infl_right, texture_r,
    #     hemi='right', view='medial',
    #     figure=fig,
    #     axes=fig.add_subplot(2, 2, 4, projection='3d')
    # )
    #
    # plt.suptitle(f"Group average apexp: {group}", fontsize=16, y=0.95)
    # plt.tight_layout()
    # plt.show()
