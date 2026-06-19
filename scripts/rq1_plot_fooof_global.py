import os
import numpy as np
import matplotlib.pyplot as plt
import pickle
from fooof import FOOOF
from fooof.plts.annotate import plot_annotated_model

np.random.seed(42)

# Plotting grandaverage power spectra
with open(os.path.join('..','results','fooof_global',"FAM_fm_grandavg.pkl"), "rb") as f:
    fm = pickle.load(f)

# cm = 1 / 2.54
# fig, ax = plt.subplots(figsize=(13 * cm, 10 * cm))

# plot_annotated_model(fm, annotate_peaks=False, plt_log=True)

plt.plot(np.log(fm.freqs), fm.power_spectrum, color="black", alpha = 0.6, linewidth=2, label = 'Original spectrum')
# plt.plot(np.log(fm.freqs), fm.fooofed_spectrum_, color="blue", alpha = 0.6, linewidth=2, label = 'Modelled spectrum')
plt.plot(np.log(fm.freqs), fm._ap_fit, color="limegreen", linestyle="--", alpha = 0.6, linewidth=2, label = 'Aperiodic component')
# plt.xticks(ticks=np.log([2, 5, 10, 20, 30, 40]), labels=[2, 5, 10, 20, 30, 40])
plt.xlabel("log(frequency)")

# plt.plot(fm.freqs, fm._ap_fit, color="#C0C0C0", linestyle="--", linewidth=2, label = 'Aperiodic component')
# plt.plot(fm.freqs, fm.fooofed_spectrum_, color="#C0C0C0", linewidth=2, label = 'Modelled spectrum')
# plt.plot(fm.freqs, fm.power_spectrum, color="#43A047", linewidth=2, label = 'Original spectrum')
# plt.xlabel("Frequency")

plt.ylabel("log(power)")
plt.title("Group-average spectra and aperiodic fit")
plt.legend()

ax = plt.gca()
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.yaxis.set_ticks_position('left')
ax.xaxis.set_ticks_position('bottom')

plt.tight_layout()

out_file = os.path.join('..','figs','fooof_global', "rq1_fooof_global_FAM.svg")

plt.savefig(
    out_file,
    dpi=300,
    bbox_inches="tight",
    transparent=True
)
