import os
import numpy as np
import pandas as pd
from neuromaps import datasets, resampling, images
from neuromaps.plotting import plot_surf_template
import matplotlib.pyplot as plt
from nilearn.image import mean_img

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

# # Receptor maps
# receptor_files = {
#     "dubois": datasets.fetch_annotation(source='dubois2015', return_single=True),
#     "galovic": datasets.fetch_annotation(source='galovic2021', return_single=True),
#     "rosaneto": datasets.fetch_annotation(source='rosaneto', return_single=True),
#     "smart": datasets.fetch_annotation(source='smart2019', return_single=True),
#     "dukart": datasets.fetch_annotation(source='dukart2018', desc='flumazenil', return_single=True),
#     "lukow": datasets.fetch_annotation(source='lukow2022', return_single=True),
#     "norgaard": datasets.fetch_annotation(source='norgaard2021', space='fsaverage', return_single=True),
# }
#
# resampled_receptors = {}
# for receptor_name, receptor_file in receptor_files.items():
#
#     # Default spaces
#     src_space = "MNI152"
#     trg_space = "MNI152"
#
#     # Special case for norgaard
#     if receptor_name == "norgaard":
#         src_space = "fsaverage"
#         trg_space = "fsaverage"
#
#     # Resample receptor maps to surface for plotting
#     receptor_resampled, _ = resampling.resample_images(
#         src=receptor_file,
#         trg=receptor_file,
#         src_space=src_space,
#         trg_space=trg_space,
#         resampling='transform_to_alt',
#         alt_spec=('fsaverage', '10k')
#     )
#     resampled_receptors[receptor_name] = receptor_resampled
#
#     # Plot receptor resampled
#     output_file = os.path.join(figs_folder, f"recep_dist_{receptor_name}.png")
#     plot_surf_template(
#         receptor_resampled,
#         template='fsaverage',
#         density='10k',
#         mask_medial=True,
#         colorbar=True
#         # output_file=output_file
#     )
#
#     # Global title
#     plt.suptitle(receptor_name, fontsize=16)
#     plt.savefig(os.path.join(figs_folder, f"recep_dist_{receptor_name}.png"), dpi=300)
#     plt.close()

# -----------------------------------
# Average apexp per group
# -----------------------------------

# List all the files in the apexp folder
apexp_folder = os.path.join(project_root, 'L1', 'data', 'sources', 'apexp')

apexp_files = [
    f for f in os.listdir(apexp_folder)
    if f.endswith(".nii") or f.endswith(".nii.gz")
]

# Keep only healthy participants
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


for group, files in group_files.items():

    # Group average of apexp
    group_avg_img = mean_img(files)

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
        mask_medial=True,
        colorbar=True
    )

    plt.suptitle(f"Group average apexp: {group}", fontsize=16)
    plt.savefig(os.path.join(figs_folder, f"groupavg_apexp_{group}.png"), dpi=300)
    plt.close()

    print(f"{group}: n = {len(files)}")