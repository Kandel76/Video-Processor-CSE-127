"""
Original Provided by Ethan Sifferman
Edited by Aadarsha Kandel

Auto-parses SPICE file for all parameters — no manual edits needed after SPICE changes.
"""

import re
import glob
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.axes_grid1.inset_locator import inset_axes, mark_inset

# ── SPICE value parser ────────────────────────────────────────────────────────
def parse_spice_val(s):
    """Convert a SPICE value string (e.g. '10k', '620p', '28u') to float."""
    s = s.strip().lower()
    # Order matters: 'meg' before 'm', 'g' before general suffix
    suffixes = [
        ('meg', 1e6), ('g', 1e9), ('t', 1e12),
        ('k', 1e3),  ('m', 1e-3), ('u', 1e-6),
        ('n', 1e-9), ('p', 1e-12), ('f', 1e-15),
    ]
    for suf, mul in suffixes:
        if s.endswith(suf):
            return float(s[:-len(suf)]) * mul
    return float(s)

# ── Parse SPICE file ──────────────────────────────────────────────────────────
spice_files = glob.glob("*.spice") + glob.glob("*.cir") + glob.glob("*.net")
if not spice_files:
    raise FileNotFoundError("No .spice/.cir/.net file found in current directory")
spice_file = spice_files[0]

R = C = None
v_high = v_low = t_on = T_period = None
sim_end = None
z_lo = z_hi = None

with open(spice_file) as f:
    for line in f:
        s = line.strip()

        # Resistor: R<name> <n+> <n-> <value>
        m = re.match(r'^R\w+\s+\S+\s+\S+\s+(\S+)', s, re.IGNORECASE)
        if m and R is None:
            R = parse_spice_val(m.group(1))

        # Capacitor: C<name> <n+> <n-> <value>
        m = re.match(r'^C\w+\s+\S+\s+\S+\s+(\S+)', s, re.IGNORECASE)
        if m and C is None:
            C = parse_spice_val(m.group(1))

        # PULSE source: PULSE(<vl> <vh> <td> <tr> <tf> <pw> <per>)
        m = re.search(r'PULSE\s*\(\s*(\S+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s*\)', s, re.IGNORECASE)
        if m:
            v_low    = parse_spice_val(m.group(1))
            v_high   = parse_spice_val(m.group(2))
            t_on     = parse_spice_val(m.group(3))
            T_period = parse_spice_val(m.group(4))

        # tran <step> <end>
        m = re.match(r'^tran\s+\S+\s+(\S+)', s, re.IGNORECASE)
        if m and sim_end is None:
            sim_end = parse_spice_val(m.group(1))

        # .measure ... FROM=<lo> TO=<hi>
        m = re.search(r'FROM\s*=\s*(\S+)\s+TO\s*=\s*(\S+)', s, re.IGNORECASE)
        if m:
            lo = parse_spice_val(m.group(1))
            hi = parse_spice_val(m.group(2))
            if z_lo is None or lo < z_lo:
                z_lo = lo
            if z_hi is None or hi > z_hi:
                z_hi = hi

if None in (R, C, v_high, t_on, T_period, sim_end):
    raise ValueError(f"Could not parse all required parameters from {spice_file}")

# Fall back to last 5% of sim time if no .measure window found
if z_lo is None or z_hi is None:
    z_lo = sim_end * 0.95
    z_hi = sim_end

# ── Derived quantities ────────────────────────────────────────────────────────
tau      = R * C
fc       = 1 / (2 * np.pi * tau)
f_pwm    = 1 / T_period
duty     = t_on / T_period
v_exp    = v_low + duty * (v_high - v_low)   # expected DC average
n_tau    = round(sim_end / tau)               # how many taus the sim runs

tau_us     = tau   * 1e6
fc_khz     = fc    * 1e-3
f_pwm_mhz  = f_pwm * 1e-6
sim_end_us = sim_end * 1e6
z_lo_us    = z_lo * 1e6
z_hi_us    = z_hi * 1e6
R_kohm     = R  * 1e-3
C_pf       = C  * 1e12

# ── Load simulation data ──────────────────────────────────────────────────────
# ngspice wrdata writes: time v(in) time v(out) → columns 0,1,2,3
data  = np.loadtxt("tran.data")
t_us  = data[:, 0] * 1e6
v_in  = data[:, 1]
v_out = data[:, 3]

# Compute measured quantities from data within the .measure window
mask_z      = (t_us >= z_lo_us) & (t_us <= z_hi_us)
vmax        = float(v_out[mask_z].max())
vmin        = float(v_out[mask_z].min())
v_avg       = float(v_out[mask_z].mean())
v_ripple_mv = (vmax - vmin) * 1e3

# ── Figure layout: main + zoomed inset ───────────────────────────────────────
fig, ax = plt.subplots(figsize=(13, 5.5))

ds = 10  # downsample for readability
ax.plot(t_us[::ds], v_in[::ds],  color="#5599dd", lw=0.8, alpha=0.7,
        label=f"v(in)  PWM  {f_pwm_mhz:.4f} MHz, {v_high:.1f} V, {duty*100:.0f}% duty")
ax.plot(t_us[::ds], v_out[::ds], color="#cc3333", lw=1.8,
        label=f"v(out)  RC filtered  (R={R_kohm:.0f} kΩ, C={C_pf:.0f} pF)")

# tau markers
y_top = v_high * 1.07
for n in range(1, n_tau + 1):
    x = n * tau_us
    if x <= sim_end_us:
        ax.axvline(x, color="darkorange", lw=0.8, ls="--", alpha=0.5)
        ax.text(x + sim_end_us * 0.005, y_top, f"{n}τ",
                fontsize=7.5, color="darkorange", va="top")

# Final tau marker bolder
final_tau_us = n_tau * tau_us
ax.axvline(final_tau_us, color="darkorange", lw=1.8, ls="--",
           label=f"{n_tau}τ = {final_tau_us:.1f} µs  (measurement point)")

# DC average line
ax.axhline(v_avg, color="green", lw=1.2, ls=":", alpha=0.8,
           label=f"DC avg = {v_avg:.4f} V  (expected {v_exp:.4f} V)")

ax.set_xlim(0, sim_end_us)
ax.set_ylim(-0.25, v_high * 1.17)
ax.set_xlabel("Time (µs)", fontsize=12)
ax.set_ylabel("Voltage (V)", fontsize=12)
ax.set_title(
    f"RC Low-Pass Filter — PWM → DC Reference  ({n_tau}τ run)\n"
    f"R = {R_kohm:.0f} kΩ  |  C = {C_pf:.0f} pF  |  τ = {tau_us:.2f} µs  |  "
    f"fc = {fc_khz:.1f} kHz  |  f_pwm = {f_pwm_mhz:.4f} MHz",
    fontsize=11.5)
ax.legend(loc="upper left", fontsize=9.5, framealpha=0.9)
ax.grid(True, alpha=0.3)

# ── Zoomed inset: ripple at measurement window ────────────────────────────────
axins = inset_axes(ax, width="32%", height="52%", loc="lower right",
                   bbox_to_anchor=(0.98, 0.04, 1, 1),
                   bbox_transform=ax.transAxes)

axins.plot(t_us[mask_z][::ds], v_in[mask_z][::ds],  color="#5599dd", lw=0.9, alpha=0.7)
axins.plot(t_us[mask_z][::ds], v_out[mask_z][::ds], color="#cc3333", lw=2.0)

ripple_color = "darkgreen"
axins.hlines(vmax, z_lo_us, z_hi_us, colors=ripple_color, ls="--", lw=1.3)
axins.hlines(vmin, z_lo_us, z_hi_us, colors=ripple_color, ls="--", lw=1.3)
axins.annotate("",
    xy=(z_lo_us + (z_hi_us - z_lo_us) * 0.1, vmin),
    xytext=(z_lo_us + (z_hi_us - z_lo_us) * 0.1, vmax),
    arrowprops=dict(arrowstyle="<->", color=ripple_color, lw=1.3))
axins.text(z_lo_us + (z_hi_us - z_lo_us) * 0.2, (vmax + vmin) / 2,
           f"{v_ripple_mv:.1f} mV p-p",
           va="center", fontsize=8, color=ripple_color,
           bbox=dict(boxstyle="round,pad=0.25", fc="white", ec=ripple_color, alpha=0.85))

axins.set_xlim(z_lo_us, z_hi_us)
axins.set_ylim(vmin - 0.15, vmax + 0.15)
axins.set_title(f"Ripple at {n_tau}τ ({z_lo_us:.1f}–{z_hi_us:.1f} µs)", fontsize=8)
axins.set_xlabel("Time (µs)", fontsize=8)
axins.set_ylabel("V (V)", fontsize=8)
axins.tick_params(labelsize=7)
axins.grid(True, alpha=0.3)

mark_inset(ax, axins, loc1=2, loc2=4, fc="none", ec="gray", lw=0.8)

# ── Summary box ──────────────────────────────────────────────────────────────
summary = (
    f"Results at {n_tau}τ = {final_tau_us:.1f} µs  (C = {C_pf:.0f} pF)\n"
    "────────────────────────────────────────\n"
    f"v(out) max:  {vmax:.4f} V\n"
    f"v(out) min:  {vmin:.4f} V\n"
    f"Ripple:      {v_ripple_mv:.1f} mV p-p\n"
    f"DC avg:      {v_avg:.4f} V  (exp. {v_exp:.4f} V)"
)
ax.text(0.42, 0.97, summary, transform=ax.transAxes,
        fontsize=8.5, va="top", ha="left", family="monospace",
        bbox=dict(boxstyle="round,pad=0.5", fc="lightyellow", ec="goldenrod", alpha=0.92))

plt.tight_layout()
plt.savefig("rc_filter_plot.png", dpi=150)
print("Saved rc_filter_plot.png")
