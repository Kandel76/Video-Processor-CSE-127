
The current design uses the following values

R=10kOhms
C=170pF

time constant = 1.7us
(will be letting it ramp for 5 time constants)
settle cycles (25MHz clk) = 213 Cycles

f(cutoff) = 93.6 kHz


PWM Configurations

f(pwm) = 6.25 MHz

Note: The system clock and the PWM clock will be different
System CLK = 25MHz
PWM CLK = 100Mhz


to run the spice simulation
''ngspice -b rc_test.spice''

