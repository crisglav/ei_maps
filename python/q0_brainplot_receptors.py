# This script creates brainplots for selected neurotransmitter distributions

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from neuromaps import datasets, resampling, images
from neuromaps.plotting import plot_surf_template

from nilearn.image import mean_img

# Figures folder
figs_folder = os.path.join('..', 'figs', 'brainmaps')
os.makedirs(figs_folder, exist_ok=True)

# Receptor maps
receptor_files = {
    "dubois": datasets.fetch_annotation(source='dubois2015', return_single=True),
    "galovic": datasets.fetch_annotation(source='galovic2021', return_single=True),
    "rosaneto": datasets.fetch_annotation(source='rosaneto', return_single=True),
    "smart": datasets.fetch_annotation(source='smart2019', return_single=True),
    "dukart": datasets.fetch_annotation(source='dukart2018', desc='flumazenil', return_single=True),
    "lukow": datasets.fetch_annotation(source='lukow2022', return_single=True),
    "norgaard": datasets.fetch_annotation(source='norgaard2021', space='fsaverage', return_single=True),
}

resampled_receptors = {}
for receptor_name, receptor_file in receptor_files.items():

    # Default spaces
    src_space = "MNI152"
    trg_space = "MNI152"

    # Special case for norgaard
    if receptor_name == "norgaard":
        src_space = "fsaverage"
        trg_space = "fsaverage"

    # Resample receptor maps to surface for plotting
    receptor_resampled, _ = resampling.resample_images(
        src=receptor_file,
        trg=receptor_file,
        src_space=src_space,
        trg_space=trg_space,
        resampling='transform_to_alt',
        alt_spec=('fsaverage', '10k')
    )
    resampled_receptors[receptor_name] = receptor_resampled

    # Plot receptor resampled
    plot_surf_template(
        receptor_resampled,
        template='fsaverage',
        density='10k',
        mask_medial=True
        # colorbar=True
    )

    # Global title
    plt.suptitle(receptor_name, fontsize=16, y=0.9)
    plt.savefig(
        os.path.join(figs_folder, f"recep_dist_{receptor_name}.png"),
        dpi=300,
        transparent=True,
        bbox_inches='tight',
        pad_inches=0
    )
    plt.close()