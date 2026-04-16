import os
import pandas as pd


# Figures folder
figs_folder = os.path.join('..', 'figs', 'brainmaps','schaefer')
os.makedirs(figs_folder, exist_ok=True)

# Load parcellated data from .csv
receptors_path = os.path.join('..', 'data', 'receptors', 'aal_spm8', 'rec_maps_aalspm8.csv')
receptor_data = pd.read_csv(receptors_path)
receptor_names = receptor_data.columns.tolist()

# Load aperiodic exponents computed on AAL SPM8