* OPENIMAGESENSOR single pixel simulation
.temp 25
.lib "sm141064.ngspice" typical
.lib "sm141064.ngspice" diode_typical

.param fnoicor=0

* power and ground
VDD VDD 0 DC 3.3
VSS VSS 0 DC 0

* Transistors (drain, gate, source, body)
* M1 = Reset, M2 = Source-follower, M3 = Row-select
M1 PD RESET VDD VSS nfet_03v3 w=3.7e-7 l=3.6e-7
M2 OUT PD VDD VSS nfet_03v3 w=1.5e-6 l=3.6e-7
M3 COL SEL OUT VSS nfet_03v3 w=3.7e-7 l=3.6e-7

* Photodiode
D1 VSS PD diode_nw2ps_03v3 area=3.9e-11

* Signals (Reset, Select, Light)
* PULSE(V_start, V_end, Delay, Rise Time, Fall Time, Hold Time, Period)
VRESET RESET 0 PULSE(0 3.3 0.25m 1u 1u 0.125m 2m)
VSEL SEL 0 PULSE(0 3.3 1.75m 1u 1u 1u 1m)

ILIGHT PD VSS PULSE(0 100pA 1m 1u 1u 0.5m 4m)

C_COL COL VSS 20f

* simulation
.tran 1m 4m uic

.control
run
plot V(PD) V(COL) V(RESET) V(SEL) V(OUT)
.endc

.end

