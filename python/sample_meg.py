import numpy as np
import matplotlib.pyplot as plt

# Reproducibility
np.random.seed(42)

# Time vector (shorter signal)
fs = 1000
duration = 1.0
t = np.arange(0, duration, 1/fs)

# Slowly varying amplitude envelope
envelope = 0.6 + 0.4 * np.sin(2 * np.pi * 0.8 * t - 0.6)

# Simulated MEG signal
signal = envelope * (
    45e-15 * np.sin(2 * np.pi * 10 * t) +
    8e-15 * np.sin(2 * np.pi * 22 * t + 0.4)
)

# Very small amount of noise
signal += 1e-15 * np.random.randn(len(t))

# Plot
fig, ax = plt.subplots(figsize=(4.5, 1.3))

ax.plot(t, signal * 1e15, color="black", lw=1.4)

ax.set_xlim(0.1, 0.9)
ax.set_xticks([])
ax.set_yticks([])

for spine in ax.spines.values():
    spine.set_visible(False)

plt.tight_layout(pad=0.05)

# Export
plt.savefig("sample_meg_signal.svg", format="svg",
            transparent=True, bbox_inches="tight")
plt.show()