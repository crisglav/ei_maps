#!/usr/bin/env python3
# This script parametrizes power spectra at each source position with fooof algorithm.
#
# Cristina Gil Ávila, C3N, 27/08/2026

import os
import json
import logging
import numpy as np
import scipy.io as sio
import nibabel as nib
import time
import pickle
from fooof import FOOOFGroup


def setup_logger(logfile, errfile):
    logger = logging.getLogger("fooof_sources")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    fmt = logging.Formatter("%(asctime)s | %(levelname)s | %(message)s")

    fh = logging.FileHandler(logfile)
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    eh = logging.FileHandler(errfile)
    eh.setFormatter(fmt)
    eh.setLevel(logging.WARNING)
    logger.addHandler(eh)

    sh = logging.StreamHandler()
    sh.setFormatter(fmt)
    logger.addHandler(sh)

    return logger


def save_apexp_nifti(apexp, grid, outname):

    dim = np.asarray(get_field(grid, "dim"), dtype=int)
    img_data = np.asarray(apexp, dtype=np.float32).reshape(dim, order='F')

    # hard coded affine
    affine = np.array([
        [10.0, 0.0, 0.0, -70.0],
        [0.0, 10.0, 0.0, -110.0],
        [0.0, 0.0, 10.0, -70.0],
        [0.0, 0.0, 0.0, 1.0]
    ], dtype=float)

    nii = nib.Nifti1Image(img_data, affine)

    nii.header.set_xyzt_units('mm')

    nib.save(nii, outname + ".nii.gz")


def main():
    ###############
    # CONFIG
    ##############
    config_file = os.path.join('..','config_megtusalen.json')
    config = json.load(open(config_file))

    # Project root
    project_root = config['path']['project_root']
    # project_root = r'C:\Users\Cristina\megtusalen'

    # FOOOF parameters
    freq_range = config['fooofband']
    max_n_peaks = config['max_n_peaks']
    peak_width_limits = config['peak_width_limits']
    aperiodic_mode = config['aperiodic_mode']
    # Rsquared threshold to assess the goodness of fit of the modelled power spectrum
    r2_thres = config['r2_thres']

    # Cortical ROIS of the AAL2 altas
    roi = np.asarray(config['roi'])

    # freq_range = [2, 45]
    # max_n_peaks = 100
    # peak_width_limits = [1, 12]
    # aperiodic_mode = 'fixed'
    #
    # # Rsquared threshold to assess the goodness of fit of the modelled power spectrum
    # r2_thres = 0.85

    # Cortical rois of the AAL atlas
    # roi = np.r_[np.arange(1, 41), np.arange(43, 71), np.arange(79, 91)]

    # Load atlas AAL template downsampled to source grid
    template = sio.loadmat(os.path.join('..', '..', 'data', 'templates','template_AAL.mat'), squeeze_me=True, struct_as_record=False)
    grid = template['grid']
    # grid = get_field(template["template"], "grid") if "template" in template else template["grid"]
    area = np.asarray(getattr(grid,'area')).astype(int)
    # area = np.asarray(get_field(grid, "area")).astype(int)
    cortical = np.isin(area, roi)
    cortical_idx = np.where(cortical)[0]

    sessions = ["L1", "L2"]

    # Loop over sessions
    for session in sessions:

        # Set power and fooof paths
        pow_path = os.path.join(project_root, session, 'data', 'sources', 'power')
        fooof_path = os.path.join(project_root, session, 'data', 'sources', 'fooof_py_27082026')

        # Create fooof folder if it doesn't exist
        os.makedirs(fooof_path, exist_ok=True)

        # List power files
        files = sorted(
            f for f in os.listdir(pow_path)
            if f.endswith(".mat")
        )

        # Set up log files
        logger = setup_logger(
            os.path.join(fooof_path, "fooof_log_py.txt"),
            os.path.join(fooof_path, "fooof_error_log_py.txt"),
        )

        logger.info("=" * 60)
        logger.info("New run started")
        logger.info("=" * 60)

        # Loop over files in this session
        for file in files:

            try:
                # Load power
                filepath = os.path.join(pow_path, file)
                powdata = sio.loadmat(filepath, squeeze_me=True, struct_as_record=False)

                # Print working with subjct ... to log file
                subject = str(powdata["subject"])
                task = str(powdata["task"])
                channel = str(powdata["channel"])
                msg = f"subject '{subject}', task '{task}', channel group '{channel}'"
                logger.info(f"Working with {msg}.")

                # Extract power
                band = getattr(powdata["band"],"sources")
                freqs = np.asarray(getattr(band,"freq"), dtype=float)
                power = np.asarray(getattr(band,"pow"), dtype=float)

                # Mask power at cortical sources
                cortical_power = power[cortical, :]

                # Initialize fooofgroup object
                fg = FOOOFGroup(
                    max_n_peaks=max_n_peaks,
                    peak_width_limits=peak_width_limits,
                    aperiodic_mode=aperiodic_mode,
                    verbose=False,
                )

                # Parametrize power spectra at all sources
                start = time.perf_counter()
                fg.fit(freqs, cortical_power, freq_range=freq_range, n_jobs=12)
                elapsed = time.perf_counter() - start

                # Log elapsed time into file
                logger.info(f"FOOOF fit took {elapsed:.2f} seconds")

                # Save fooof object to disk
                outpath = os.path.join(fooof_path, f"{subject}_{task}_{channel}_fooof_sources.pkl")
                with open(outpath, "wb") as f:
                    pickle.dump([config, subject, task, channel, fg], f)



                # # Extract fitted parameters
                # results = fg.get_results()
                #
                # # Get the aperiodic exponent
                # apexp_temp = np.array([
                #     res.aperiodic_params[-1] if res is not None else np.nan
                #     for res in results
                # ])
                #
                # r2 = np.array([
                #     res.r_squared if res is not None else np.nan
                #     for res in results
                # ])
                #
                # apexp = np.full(cortical.shape, np.nan, dtype=float)
                # apexp[cortical] = apexp_temp
                #
                # apexp_clean = apexp.copy()
                # cortical_apexp = apexp_clean[cortical]
                # cortical_apexp[r2 < r2_thres] = np.nan
                # apexp_clean[cortical] = cortical_apexp
                #
                # bad_sources = cortical_idx[r2 < r2_thres]
                #
                # if bad_sources.size == 0:
                #     logger.info(
                #         f"OK | {subject} {task} | nBad=0 | "
                #         f"r2_thres={r2_thres:.2f}"
                #     )
                # else:
                #     logger.warning(
                #         f"BAD | {subject} {task} | nBad={bad_sources.size} | "
                #         f"r2_thres={r2_thres:.2f} | "
                #         f"idx={bad_sources.tolist()}"
                #     )
                #
                # fooofdata = {
                #     "subject": subject,
                #     "task": task,
                #     "channel": channel,
                #     "whitener": powdata.get("whitener", None),
                #     "lambda": powdata.get("lambda", None),
                #     "taper": powdata.get("taper", None),
                #     "apexp": apexp,
                #     "apexp_clean": apexp_clean,
                #     "r_squared": r2,
                #     "aperiodic_params": np.vstack([
                #         res.aperiodic_params if res is not None else np.full(2, np.nan)
                #         for res in results
                #     ]),
                # }
                #
                # # Save to disk
                # outpath = os.path.join(fooof_path, f"{subject}_{task}_{channel}_fooof_sources.mat")
                # sio.savemat(outpath, fooofdata, do_compression=False)
                #
                # out_nii = os.path.join(
                #     fooof_path,
                #     f"{subject}_{task}_{channel}_apexp_clean"
                # )
                #
                # save_apexp_nifti(apexp_clean, template["grid"], out_nii)

                logger.info(f"Saved {outpath}")

            except Exception as exc:
                logger.exception(f"Failed processing {file}: {exc}")

if __name__ == "__main__":
    import multiprocessing as mp
    mp.freeze_support()
    main()