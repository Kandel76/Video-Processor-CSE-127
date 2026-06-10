To run a simulation, just run "ngspice light\_pixel\_sim.sp" and it'll automatically bring up a graph.

All current .sp files simulate a single pixel resetting and integrating 16 times over the course of ~2500 cycles. This is a ~2500 cycles out of ~3500 cycles avaliable per frame, as ~1000 cycles are required to slowly output bits to memory.

Due to the short timeframe for reset and integration, it seems all voltages outputted to the adc will span between 1.7V and 1.4V. 

Simulation light values:
Photocurrent = Power * Responsiveness (I = P * R)
Power = Intensity * Area (P = i * A)
I = i * A * R

R (standard estimate) = 0.3 A/W
A = 3.8e-11 m^2
i = 0.01 W/m^2 to 500 W/m^2 (1-50k lux)

I = 11.4fA to 0.57nA




