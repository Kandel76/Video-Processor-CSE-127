import numpy as np
import matplotlib.pyplot as plt

data = np.loadtxt("tb_results.txt")

# From txt file the time/value pairs
t   = data[:,0]      # time (all times should match)
clk = data[:,1]
vinp= data[:,3]
vinm= data[:,5]
q   = data[:,7]
qb  = data[:,9]

# Use actual clock swing as VDD
VDD = float(clk.max())
VTH_CLK = VDD/2
T_SETTLE = 0.5e-9

def interp(tq, t, y):
    return np.interp(tq, t, y)

above = clk > VTH_CLK
# falling edge sampling (often correct for dynamic comparators)
fall_idx = np.where((above[:-1]) & (~above[1:]))[0] + 1
t_edges = t[fall_idx]

t_samp = t_edges + T_SETTLE
mask = (t_samp >= t[0]) & (t_samp <= t[-1])
t_samp = t_samp[mask]

vinp_s = interp(t_samp, t, vinp)
vinm_s = interp(t_samp, t, vinm)
q_s    = interp(t_samp, t, q)
qb_s   = interp(t_samp, t, qb)

decision = (q_s > qb_s).astype(int)

# Compute offset
trans = np.where((decision[:-1] == 0) & (decision[1:] == 1))[0]

if len(trans) == 0:
    offset_mv = 0
    est_threshold = np.nan
else:
    k = trans[0]
    est_threshold = vinp_s[k+1]   # first HIGH decision point
    offset_mv = (est_threshold - vinm_s.mean()) * 1000

# Plot
plt.figure(figsize=(9,5))

plt.step(vinp_s, decision*VDD, where="post", label="Decision")
plt.axvline(vinm_s.mean(), linestyle="--", label=f"Vinm = {vinm_s.mean():.3f} V")

if not np.isnan(est_threshold):
    plt.axvline(est_threshold, linestyle=":", label=f"Vth = {est_threshold:.3f} V")

plt.title(f"Comparator Offset = {offset_mv:.1f} mV")
plt.xlabel("Vinp sampled (V)")
plt.ylabel("Decision (0 or VDD)")
plt.grid(True)
plt.legend()
plt.show()