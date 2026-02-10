from neuromaps import datasets, resampling
from neuromaps.transforms import mni152_to_fsaverage

dubois      = datasets.fetch_annotation(source='dubois2015', return_single=True)
# fsaverage   = datasets.fetch_atlas(atlas='fsaverage', density='10k') # This is not needed

# # Resample dubois (MNI152) -> fsaverage 10k surface (LH, RH)
# dubois_fsavg, _ = resampling.resample_images(
#     src=dubois,
#     trg=dubois,              # dummy placeholder; not used for transform_to_alt
#     src_space='MNI152',
#     trg_space='MNI152',      # irrelevant here
#     resampling='transform_to_alt',
#     alt_spec=('fsaverage', '10k')
# )

# Low level function - returns (LH, RH) Gifti images
dubois_fsavg = mni152_to_fsaverage(dubois, fsavg_density='10k', method='linear')

# Plot the surface data
import matplotlib.pyplot as plt
from neuromaps.plotting import plot_surf_template
fig = plot_surf_template(dubois_fsavg, template='fsaverage', density='10k', mask_medial=True)
plt.show()




# Volumetric view
from nilearn import plotting
view = plotting.view_img(dubois)  # interactive in Jupyter
view
