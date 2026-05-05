#!/usr/bin/env python3

import os
import logging
import numpy as np
import scipy.io as sio
import nibabel as nib
import time
from fooof import FOOOFGroup



def get_field(obj, name):
    return getattr(obj, name) if hasattr(obj, name) else obj[name]


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


def save_apexp_nifti(apexp, template, outname):

    grid = get_field(template, "grid")
    mri = get_field(template, "mri")

    dim = np.asarray(get_field(grid, "dim"), dtype=int)
    affine = np.asarray(get_field(mri, "transform"), dtype=float)

    img_data = np.asarray(apexp, dtype=float).reshape(dim, order="F")

    nii = nib.Nifti1Image(img_data, affine)
    nib.save(nii, outname + ".nii.gz")


def main():

    # Project root
    project_root = r'C:\Users\Cristina\megtusalen'

    # FOOOF parameters
    freq_range = [2, 45]
    max_n_peaks = 100
    peak_width_limits = [1, 12]
    aperiodic_mode = 'fixed'

    # Rsquared threshold to assess the goodness of fit of the modelled power spectrum
    r2_thres = 0.85

    # Cortical rois of the AAL atlas
    roi = np.r_[np.arange(1, 41), np.arange(43, 71), np.arange(79, 91)]
    # roi = [1]

    # Load atlas AAL template downsampled to grid source
    template = sio.loadmat(os.path.join('..','matlab','templates','template_AAL.mat'), squeeze_me=True, struct_as_record=False)
    grid = get_field(template["template"], "grid") if "template" in template else template["grid"]
    area = np.asarray(get_field(grid, "area")).astype(int)
    cortical = np.isin(area, roi)
    cortical_idx = np.where(cortical)[0]

    sessions = ["L1", "L2"]

    for session in sessions:
        pow_path = os.path.join(project_root, session, 'data', 'sources', 'power')
        fooof_path = os.path.join(project_root, session, 'data', 'sources', 'fooof_py_infpeaks')

        # Create folders if they don't exist
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

        for file in files:

            try:
                filepath = os.path.join(pow_path, file)
                powdata = sio.loadmat(filepath, squeeze_me=True, struct_as_record=False)

                subject = str(powdata["subject"])
                task = str(powdata["task"])
                channel = str(powdata["channel"])

                msg = f"subject '{subject}', task '{task}', channel group '{channel}'"
                out_mat = os.path.join(
                    fooof_path,
                    f"{subject}_{task}_{channel}_fooof_sources.mat"
                )

                # Skip if already computed
                if os.path.exists(out_mat):
                    logger.info(f"Skipping {msg}: FOOOF file already exists.")
                    continue

                logger.info(f"Working with {msg}.")

                band = get_field(powdata["band"], "sources")
                freqs = np.asarray(get_field(band, "freq"), dtype=float)
                power = np.asarray(get_field(band, "pow"), dtype=float)

                cortical_power = power[cortical, :]

                fg = FOOOFGroup(
                    peak_width_limits=peak_width_limits,
                    max_n_peaks=max_n_peaks,
                    aperiodic_mode=aperiodic_mode,
                    verbose=False,
                )

                start = time.perf_counter()
                fg.fit(freqs, cortical_power, freq_range=freq_range, n_jobs=12)
                elapsed = time.perf_counter() - start
                logger.info(f"FOOOF fit took {elapsed:.2f} seconds")

                results = fg.get_results()

                apexp_temp = np.array([
                    res.aperiodic_params[-1] if res is not None else np.nan
                    for res in results
                ])

                r2 = np.array([
                    res.r_squared if res is not None else np.nan
                    for res in results
                ])

                apexp = np.full(cortical.shape, np.nan, dtype=float)
                apexp[cortical] = apexp_temp

                apexp_clean = apexp.copy()
                cortical_apexp = apexp_clean[cortical]
                cortical_apexp[r2 < r2_thres] = np.nan
                apexp_clean[cortical] = cortical_apexp

                bad_sources = cortical_idx[r2 < r2_thres]

                if bad_sources.size == 0:
                    logger.info(
                        f"OK | {subject} {task} | nBad=0 | "
                        f"r2_thres={r2_thres:.2f}"
                    )
                else:
                    logger.warning(
                        f"BAD | {subject} {task} | nBad={bad_sources.size} | "
                        f"r2_thres={r2_thres:.2f} | "
                        f"idx={bad_sources.tolist()}"
                    )

                fooofdata = {
                    "subject": subject,
                    "task": task,
                    "channel": channel,
                    "whitener": powdata.get("whitener", None),
                    "lambda": powdata.get("lambda", None),
                    "taper": powdata.get("taper", None),
                    "apexp": apexp,
                    "apexp_clean": apexp_clean,
                    "r_squared": r2,
                    "aperiodic_params": np.vstack([
                        res.aperiodic_params if res is not None else np.full(2, np.nan)
                        for res in results
                    ]),
                }

                sio.savemat(out_mat, fooofdata, do_compression=False)

                out_nii = os.path.join(
                    fooof_path,
                    f"{subject}_{task}_{channel}_apexp_clean"
                )

                save_apexp_nifti(apexp_clean, template, out_nii)

                logger.info(f"Saved {out_mat}")

            except Exception as exc:
                logger.exception(f"Failed processing {file}: {exc}")

if __name__ == "__main__":
    import multiprocessing as mp
    mp.freeze_support()
    main()