import os
import numpy as np
import nibabel as nib
from neuromaps import datasets, resampling, stats, images, nulls

# Path to fooof data
project_root = r'C:\Users\Cristina\megtusalen'
apexp_file = os.path.join(project_root,'data','sources','apexp','FAM-001_rECpost_MEGMAG_apexp_clean.nii')

# Path to receptor map
dubois_file = datasets.fetch_annotation(source='dubois2015', return_single=True)

# Path to parcellation (brain mask)
# Note that we use a fake parcellation with as many regions as source locations inside the brain to decrease the computation of null models
parcellation_file = os.path.join(project_root,'data','sources','apexp','parcellation.nii')
parcellation_data = nib.load(parcellation_file)

# Resample dubois to the apexp grid (lower resolution)
dubois, apexp = resampling.resample_images(src=dubois_file, trg=apexp_file,
                                            src_space='MNI152',
                                            trg_space='MNI152',
                                            resampling='transform_to_trg')

# Correlate dubois and apexp
corr = stats.compare_images(dubois, apexp)
print(f'Correlation: r = {corr:.04f}')


# Get binary mask from all the values in parcellation_data that are non-zero
brain_mask = parcellation_data.get_fdata() != 0
brain_mask_flat = brain_mask.flatten()

# Extract dubois data in the brain mask
dubois_data = images.load_data(dubois)
dubois_data_flat = dubois_data.flatten()
dubois_data_flat = dubois_data_flat[brain_mask_flat]

# Extract apexp data in the brain mask
apexp_data = images.load_data(apexp)
apexp_data_flat = apexp_data.flatten()
apexp_data_flat = apexp_data_flat[brain_mask_flat]
#%%
# Compute the spatial nulls
n_perm = 1000
rotated = nulls.burt2020(dubois_data_flat, atlas = 'mni152', density = '2mm', parcellation=parcellation_data, n_perm=n_perm, n_proc=12, seed=1234)
#%%
# Embed spatial nulls into the original 3d grid
nulls_4d = np.zeros(brain_mask.shape + (n_perm,), dtype=rotated.dtype)
nulls_4d.reshape(-1, n_perm)[brain_mask_flat, :] = rotated
#%%
# Compute correlation with pvalue
corr, pval = stats.compare_images(dubois, apexp, nulls=nulls_4d)
print(f'Correlation: r = {corr:.04f}, p = {pval:.04f}')