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
from datetime import datetime

def setup_logger(logfile):
    logger = logging.getLogger('fooof_sources')
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    fmt = logging.Formatter('%(asctime)s | %(levelname)s | %(message)s')

    fh = logging.FileHandler(logfile)
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    sh = logging.StreamHandler()
    sh.setFormatter(fmt)
    logger.addHandler(sh)

    return logger


def main():
    # ---------------
    # Config
    #----------------
    config_file = os.path.join('..','config_megtusalen.json')
    config = json.load(open(config_file))

    # Date
    date = datetime.now().strftime('%Y%m%d')

    # Project root
    project_root = config['path']['project_root']

    # FOOOF parameters
    freq_range = config['fooofband']
    max_n_peaks = config['max_n_peaks']
    peak_width_limits = config['peak_width_limits']
    aperiodic_mode = config['aperiodic_mode']
    # Rsquared threshold to assess the goodness of fit of the modelled power spectrum
    r2_thres = config['r2_thres']

    # Cortical ROIS of the AAL2 altas
    roi = np.asarray(config['roi'])

    # Load atlas AAL template downsampled to source grid
    template = sio.loadmat(os.path.join('..', '..', 'data', 'templates','template_AAL.mat'), squeeze_me=True, struct_as_record=False)
    grid = template['grid']
    area = np.asarray(getattr(grid,'area')).astype(int)
    cortical = np.isin(area, roi)
    cortical_idx = np.where(cortical)[0]

    sessions = ['L1', 'L2']

    # Loop over sessions
    for session in sessions:

        # Set power and fooof paths
        pow_path = os.path.join(project_root, session, 'data', 'sources', 'power')
        fooof_path = os.path.join(project_root, session, 'data', 'sources', f'fooof_py_{date}')

        # Create fooof folder if it doesn't exist
        os.makedirs(fooof_path, exist_ok=True)

        # List power files
        files = sorted(
            f for f in os.listdir(pow_path)
            if f.endswith('.mat')
        )

        # Set up log files
        logger = setup_logger(
            os.path.join(fooof_path, f'fooof_log_{date}.txt'),
        )

        logger.info('=' * 60)
        logger.info('New run started')
        logger.info('=' * 60)

        # Loop over files in this session
        for file in files:

            try:
                # Load power
                filepath = os.path.join(pow_path, file)
                powdata = sio.loadmat(filepath, squeeze_me=True, struct_as_record=False)

                # Print working with subjct ... to log file
                subject = str(powdata['subject'])
                task = str(powdata['task'])
                channel = str(powdata['channel'])
                msg = f"subject '{subject}', task '{task}', channel group '{channel}'"
                logger.info(f'Working with {msg}.')

                # Extract power
                band = getattr(powdata['band'],'sources')
                freqs = np.asarray(getattr(band,'freq'), dtype=float)
                power = np.asarray(getattr(band,'pow'), dtype=float)

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
                logger.info(f'FOOOF fit took {elapsed:.2f} seconds')

                # Save fooof object to disk
                outpath = os.path.join(fooof_path, f'{subject}_{task}_{channel}_fooof_sources.pkl')
                fooofdata = {
                    'config': config,
                    'subject': subject,
                    'task': task,
                    'channel': channel,
                    'fg': fg
                }
                with open(outpath, 'wb') as f:
                    pickle.dump(fooofdata, f)

                # Extract fitted parameters
                results = fg.get_results()

                # Get the aperiodic exponent
                apexp_temp = np.array([
                    res.aperiodic_params[-1] if res is not None else np.nan
                    for res in results
                ])

                # Get aperiodic offset
                apoff_temp = np.array([
                    res.aperiodic_params[1] if res is not None else np.nan
                    for res in results
                    ])

                # Get R2
                r2 = np.array([
                    res.r_squared if res is not None else np.nan
                    for res in results
                ])

                # Save apexp on cortical sources
                apexp = np.full(cortical.shape, np.nan, dtype=float)
                apexp[cortical] = apexp_temp

                # Discard apexp in positions where R2 is lower than threshold
                apexp_clean = apexp.copy()
                cortical_apexp = apexp_clean[cortical]
                cortical_apexp[r2 < r2_thres] = np.nan
                apexp_clean[cortical] = cortical_apexp

                apoff = np.full(cortical.shape, np.nan, dtype=float)
                apoff[cortical] = apoff_temp
                apoff_clean = apoff.copy()
                cortical_apoff = apoff_clean[cortical]
                cortical_apoff[r2 < r2_thres] = np.nan
                apoff_clean[cortical] = cortical_apoff

                fooofdata = {
                    'subject': subject,
                    'task': task,
                    'channel': channel,
                    'whitener': powdata.get('whitener', None),
                    'lambda': powdata.get('lambda', None),
                    'taper': powdata.get('taper', None),
                    'apexp': apexp,
                    'apexp_clean': apexp_clean,
                    'apoff_clean': apoff_clean,
                    'r_squared': r2,
                    'aperiodic_params': np.vstack([
                        res.aperiodic_params if res is not None else np.full(2, np.nan)
                        for res in results
                    ]),
                }

                # Save to disk
                outpath = os.path.join(fooof_path, f'{subject}_{task}_{channel}_fooof_sources.mat')
                sio.savemat(outpath, fooofdata, do_compression=False)

                logger.info(f'Saved {outpath}')

            except Exception as exc:
                logger.exception(f'Failed processing {file}: {exc}')

if __name__ == '__main__':
    import multiprocessing as mp
    mp.freeze_support()
    main()