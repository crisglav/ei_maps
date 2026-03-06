import os
import nibabel as nib
from neuromaps import datasets, resampling, stats, images, nulls

# Load fooof data
project_root = r'C:\Users\Cristina\megtusalen'
apexp_file = os.path.join(project_root,'data','sources','apexp','FAM-001_rECpost_MEGMAG_apexp_clean.nii')
mask_file = os.path.join(project_root,'data','sources','apexp','parcellation.nii')

# Receptor map
dubois_file = datasets.fetch_annotation(source='dubois2015', return_single=True)

# Resample dubois to the apexp grid (lower resolution)
dubois, apexp = resampling.resample_images(src=dubois_file, trg=apexp_file,
                                            src_space='MNI152',
                                            trg_space='MNI152',
                                            resampling='transform_to_trg')

# # Resample apexp to dubois resolution
# dubois, apexp = resampling.resample_images(src=dubois_file, trg=apexp_file,
#                                             src_space='MNI152',
#                                             trg_space='MNI152',
#                                             resampling='transform_to_src'
#                                            )
# # Resample apexp and dubois to another resolution
# dubois, apexp = resampling.resample_images(src=dubois_file, trg=apexp_file,
#                                             src_space='MNI152',
#                                             trg_space='MNI152',
#                                             resampling='transform_to_alt',
#                                             alt_spec= ('MNI152', '3mm')
#                                            )

# Correlate dubois and apexp
corr = stats.compare_images(dubois, apexp)
print(f'Correlation: r = {corr:.04f}')

# Test correlation with a spatial null (variogram method)
apexp_data = images.load_data(apexp)
apexp_data = apexp_data.flatten()
rotated = nulls.burt2020(apexp_data, atlas = 'mni152', density = '1mm', parcellation=mask_file, n_perm=10, seed=1234)

# Test correlation with a spatial null (variogram method)
dubois_data = images.load_data(dubois)
dubois_data = dubois_data.flatten()
rotated = nulls.burt2020(dubois_data, atlas = 'mni152', density = '1mm', parcellation=dubois_data, n_perm=10, seed=1234)
print(rotated.shape)

