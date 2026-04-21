# Brainplots of receptors previously parcellated to Schaefer 100

import os
import numpy as np
import pandas as pd
from matplotlib.colors import ListedColormap
from netneurotools import datasets, plotting

# Figures folder
figs_folder = os.path.join('../..', 'figs', 'brainmaps', 'schaefer')
os.makedirs(figs_folder, exist_ok=True)

# Load parcellated data from .csv
receptors_path = os.path.join('../..', 'data', 'receptors', 'schaefer100', 'rec_maps_schaefer100.csv')
receptor_data = pd.read_csv(receptors_path)
receptor_names = receptor_data.columns.tolist()

# Load annotation for plotting
annot = datasets.fetch_schaefer2018('fsaverage')['100Parcels7Networks']

# Colormap from hansen 2022
cmap = np.genfromtxt('../colourmap.csv', delimiter=',')
cmap_div = ListedColormap(cmap)

# Brainplots
for receptor_name in receptor_names:
    values = receptor_data[receptor_name].to_numpy()

    brain = plotting.plot_fsaverage(
        data=values,
        lhannot=str(annot.lh),
        rhannot=str(annot.rh),
        colormap=cmap_div,   # or use "plasma"
        views=["lat", "med"],
        data_kws={"representation": "wireframe"},
    )

    brain.save_image(os.path.join(figs_folder, f"{receptor_name}.png"))