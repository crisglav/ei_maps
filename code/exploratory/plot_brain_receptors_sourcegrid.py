# This script creates plots for weighted-averaged neurotransmitter receptor maps
#
# Cristina Gil Ávila, C3N, 10/09/2026

import os
import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import zscore
from neuromaps import datasets, resampling, images
from neuromaps.plotting import plot_surf_template
from neuromaps.images import construct_shape_gii
import nibabel as nib

# -----------------------
# Config
# -----------------------
# Figures folder
figs_folder = os.path.join('..', '..', 'figs', 'brainmaps','receptors')
os.makedirs(figs_folder, exist_ok=True)

config_weighted = True
weighted_groups = {
    'mGluR5': {'dubois': 28, 'rosaneto': 22, 'smart': 73},
    'NMDA': {'galovic': 29},
    'GABA_flumazenil': {'dukart': 6, 'norgaard': 16},
    'GABA_a5': {'lukow': 10},
    'ACh_a4b2': {'hillmer': 30},
    'ACh_M1': {'naganawa': 24},
}

# Source grid, brain mask - ones at inside brain locations (2459)
parcellation_file = os.path.join('..', '..', 'data', 'templates', 'parcellation.nii')
parcellation_img = nib.load(parcellation_file)
brain_mask = parcellation_img.get_fdata() != 0

# Receptors path
receptors_path = os.path.join('..', '..', 'data', 'prepared_receptors')

# -----------------------
# Load receptors
# -----------------------
resampled_receptors = {}
for fname in os.listdir(receptors_path):
    if fname.endswith('.nii') or fname.endswith('.nii.gz'):
        name = fname.replace('.nii.gz', '').replace('.nii', '')
        path = os.path.join(receptors_path, fname)
        resampled_receptors[name] = nib.load(path)

print(f'Loaded {len(resampled_receptors)} receptors')

# -----------------------
# Resample receptors to surface 10k
# -----------------------
surf_receptors = {}

for receptor_name, receptor_file in resampled_receptors.items():
    # Extract receptor data in the brain mask
    receptor_data = images.load_data(receptor_file)
    receptor_data = receptor_data[brain_mask]

    print(f'Resampling receptor: {receptor_name}')
    print(f'Min = {np.nanmin(receptor_data) :.4g}, max = {np.nanmax(receptor_data) :.4g}')

    # Default spaces
    src_space = "MNI152"
    trg_space = "MNI152"

    # # Special case for norgaard
    # if receptor_name == "norgaard":
    #     src_space = "fsaverage"
    #     trg_space = "fsaverage"

    receptor_resampled, _ = resampling.resample_images(
        src=receptor_file,
        trg=receptor_file,
        src_space=src_space,
        trg_space=trg_space,
        resampling='transform_to_alt',
        alt_spec=('fsaverage', '10k')
    )

    surf_receptors[receptor_name] = receptor_resampled

# -----------------------
# Plot
# -----------------------
for receptor_name, receptor_file in surf_receptors.items():
    lh_img, rh_img = receptor_file
    lh = images.load_data(lh_img).astype(float)
    rh = images.load_data(rh_img).astype(float)
    vmin = np.nanmin([np.nanmin(lh),np.nanmin(rh)])
    vmax = np.nanmax([np.nanmax(lh),np.nanmax(rh)])

    print(f'Surf values: {receptor_name}')
    print(f'Min = {vmin :.4g}, max = {vmax :.4g}')



    # Plot the weighted average receptor map in surface
    plot_surf_template(
        receptor_file,
        template='fsaverage',
        density='10k',
        mask_medial=True,
        colorbar=True,
        cmap='plasma',
        vmin=vmin,
        vmax=vmax,
        cbar_vmin = vmin,
        cbar_vmax = vmax
    )

    # Global title
    plt.suptitle(receptor_name, fontsize=16, y=0.95)
    plt.savefig(
        os.path.join(figs_folder, f"{receptor_name}_cb_plasma.png"),
        dpi=300,
        transparent=True,
        bbox_inches='tight',
        pad_inches=0
    )
    plt.close()


# # -----------------------
# # Fetch receptors
# # -----------------------
# receptor_files = {
#     # Glutamate
#     'dubois': datasets.fetch_annotation(source='dubois2015', return_single=True),
#     'galovic': datasets.fetch_annotation(source='galovic2021', return_single=True),
#     'rosaneto': datasets.fetch_annotation(source='rosaneto', return_single=True),
#     'smart': datasets.fetch_annotation(source='smart2019', return_single=True),
#
#     # GABA
#     'dukart': datasets.fetch_annotation(source='dukart2018', desc='flumazenil', return_single=True),
#     'lukow': datasets.fetch_annotation(source='lukow2022', return_single=True),
#     'norgaard': datasets.fetch_annotation(source='norgaard2021', space='fsaverage', return_single=True),
#
#     # Acetylcholine
#     'hillmer': datasets.fetch_annotation(source='hillmer2016', space='MNI152', return_single=True),
#     'naganawa': datasets.fetch_annotation(source='naganawa2020', space='MNI152', return_single=True),
# }
#
# # -----------------------
# # Resample receptors to source grid
# # -----------------------
# resampled_receptors = {}
#
# for receptor_name, receptor_file in receptor_files.items():
#     print(f'Resampling receptor: {receptor_name}')
#
#     receptor_resampled, _ = resampling.resample_images(
#         src=receptor_file,
#         trg=parcellation_file,
#         src_space='MNI152',
#         trg_space='MNI152',
#         resampling='transform_to_trg',
#     )
#
#     resampled_receptors[receptor_name] = receptor_resampled
#
# # -----------------------
# # Weighted average
# # -----------------------
# weighted_groups = {
#     'mGluR5': {'dubois': 28, 'rosaneto': 22, 'smart': 73},
#     'NMDA': {'galovic': 29},
#     'GABA_flumazenil': {'dukart': 6, 'norgaard': 16},
#     'GABA_a5': {'lukow': 10},
#     'ACh_a4b2': {'hillmer': 30},
#     'ACh_M1': {'naganawa': 24},
# }
#
# final_receptors = {}
#
# for new_name, components in weighted_groups.items():
#     print(f'Creating weighted receptor: {new_name}')
#
#     weighted_sum = None
#     total_weight = 0
#
#     for receptor_name, weight in components.items():
#         data = images.load_data(resampled_receptors[receptor_name]).astype(np.float64)
#
#         # Zscore data inside brain
#         zdata = np.zeros_like(data, dtype=np.float64)
#         zdata[brain_mask] = zscore(data[brain_mask], axis=None, nan_policy='omit' )
#
#         if weighted_sum is None:
#             weighted_sum = np.zeros_like(zdata, dtype=np.float64)
#
#         weighted_sum += weight * zdata
#         total_weight += weight
#
#     avg_data = weighted_sum / total_weight
#
#     ref_img = resampled_receptors[next(iter(components))]
#     final_receptors[new_name] = nib.Nifti1Image(
#         avg_data,
#         ref_img.affine,
#         ref_img.header,
#     )



# # -----------------------
# # Resample receptors to surface 10k, plot
# # -----------------------
# resampled_receptors = {}
#
# for receptor_name, receptor_file in receptor_files.items():
#     print(f'Resampling receptor: {receptor_name}')
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
#     receptor_resampled, _ = resampling.resample_images(
#         src=receptor_file,
#         trg=receptor_file,
#         src_space=src_space,
#         trg_space=trg_space,
#         resampling='transform_to_alt',
#         alt_spec=('fsaverage', '10k')
#     )
#
#     resampled_receptors[receptor_name] = receptor_resampled
#
#     if not(config_weighted):
#         # Plot receptor resampled
#         plot_surf_template(
#             receptor_resampled,
#             template='fsaverage',
#             density='10k',
#             mask_medial=True,
#             cmap='plasma'
#             # colorbar=True
#         )
#
#         # Global title
#         plt.suptitle(receptor_name, fontsize=16, y=0.9)
#         plt.savefig(
#             os.path.join(figs_folder, f"recep_{receptor_name}_plasma.png"),
#             dpi=300,
#             transparent=True,
#             bbox_inches='tight',
#             pad_inches=0
#         )
#         plt.close()
#
# # -----------------------
# # Perform weighted average and plot
# # -----------------------
#
# if config_weighted:
#     receptors_weighted = {}
#
#     # Perform a weighted average on the surface-resampled receptors
#     for receptor_type, studies in weighted_groups.items():
#         weighted_lh = None
#         weighted_rh = None
#         total_weight = 0
#
#         for study, weight in studies.items():
#
#             lh_img, rh_img = resampled_receptors[study]
#
#             lh = images.load_data(lh_img).astype(float)
#             rh = images.load_data(rh_img).astype(float)
#
#             # valid vertices
#             valid_lh = np.isfinite(lh)
#             valid_rh = np.isfinite(rh)
#
#             z_lh = np.full_like(lh, np.nan)
#             z_rh = np.full_like(rh, np.nan)
#
#             z_lh[valid_lh] = zscore(lh[valid_lh], nan_policy='omit')
#             z_rh[valid_rh] = zscore(rh[valid_rh], nan_policy='omit')
#
#             if weighted_lh is None:
#                 weighted_lh = np.zeros_like(z_lh)
#                 weighted_rh = np.zeros_like(z_rh)
#
#             weighted_lh[valid_lh] += weight * z_lh[valid_lh]
#             weighted_rh[valid_rh] += weight * z_rh[valid_rh]
#
#             total_weight += weight
#
#         avg_lh = weighted_lh / total_weight
#         avg_rh = weighted_rh / total_weight
#
#         avg_lh = zscore(avg_lh)
#         avg_rh = zscore(avg_rh)
#
#         lh_gii = construct_shape_gii(avg_lh)
#         rh_gii = construct_shape_gii(avg_rh)
#
#         avg_map = (lh_gii, rh_gii)
#
#         receptors_weighted[receptor_type] = avg_map
#
#         vmin = np.nanmin([np.nanmin(avg_lh),np.nanmin(avg_rh)])
#         vmax = np.nanmax([np.nanmax(avg_lh),np.nanmax(avg_rh)])
#
#         # Plot the weighted average receptor map in surface
#         plot_surf_template(
#             avg_map,
#             template='fsaverage',
#             density='10k',
#             mask_medial=True,
#             colorbar=True,
#             cmap='plasma',
#             vmin=vmin,
#             vmax=vmax,
#             cbar_vmin = vmin,
#             cbar_vmax = vmax
#         )
#
#         # Global title
#         plt.suptitle(receptor_type, fontsize=16, y=0.95)
#         plt.savefig(
#             os.path.join(figs_folder, f"{receptor_type}_cb_plasma.png"),
#             dpi=300,
#             transparent=True,
#             bbox_inches='tight',
#             pad_inches=0
#         )
#         plt.close()
#
