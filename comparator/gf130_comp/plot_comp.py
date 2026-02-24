import matplotlib.pyplot as plt
import numpy as np

# Load data from the 'wrdata' output
data = np.loadtxt('offset.txt')

time = data[:, 0] * 1e9  # Convert to ns
clk  = data[:, 1]
vinp = data[:, 3]
vinm = data[:, 5]
q    = data[:, 7]
qb   = data[:, 9]

fig, axes = plt.subplots(5, 1, figsize=(12, 10), sharex=True)

# Plot Clock
axes[0].step(time, clk, where='post', color='tab:blue')
axes[0].set_ylabel('Clock (V)')

# Plot Inputs with Reference Line
axes[1].plot(time, vinp, label='Vin+ (Signal)', color='tab:orange', linewidth=2)
axes[1].axhline(y=2.5, color='black', linestyle='--', label='2.5V Threshold')
axes[1].set_ylabel('Inputs (V)')
axes[1].legend(loc='upper right')

# Plot Reference (to show it's steady)
axes[2].plot(time, vinm, color='tab:green')
axes[2].set_ylabel('Vin- (Ref)')

# Plot Outputs
axes[3].step(time, q, where='post', color='tab:red', linewidth=1.5)
axes[3].set_ylabel('Output Q')

axes[4].step(time, qb, where='post', color='tab:purple', linewidth=1.5)
axes[4].set_ylabel('Output QB')

plt.xlabel('Time (ns)')
plt.suptitle('Multi-Value Threshold Verification', fontsize=16)
plt.tight_layout(rect=[0, 0.03, 1, 0.95])
plt.savefig('advanced_test_results.png')
plt.show()