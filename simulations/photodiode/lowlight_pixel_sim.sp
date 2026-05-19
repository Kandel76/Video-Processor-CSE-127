* OPENIMAGESENSOR single pixel simulation
.temp 25
.lib "sm141064.ngspice" typical
.lib "sm141064.ngspice" diode_typical

.param fnoicor=0

* power and ground
VDD VDD 0 DC 3.3
VSS VSS 0 DC 0
VADC ADC 0 DC 0

* Transistors (drain, gate, source, body)
* M1 = Reset, M2 = Source-follower, M3 = Row-select
M1 PD RESET VDD VSS nfet_03v3 w=3.7e-7 l=3.6e-7
M2 OUT PD VDD VSS nfet_03v3 w=1.5e-6 l=3.6e-7
M3 COL SEL OUT VSS nfet_03v3 w=3.7e-7 l=3.6e-7

* Photodiode
* Dimensions of 6.815um x 6.83um with 1.83um x 4.475 cutout
D1 VSS PD diode_nw2ps_03v3 area=3.835e-11 pj=2.725e-5

* Signals (Reset, Select, Light)
* PULSE(V_start, V_end, Delay, Rise Time, Fall Time, Hold Time, Period)
VRESET RESET 0 PULSE(0 3.3 0 10n 10n 200n 6000n)
VSEL SEL 0 PULSE(0 3.3 5750n 10n 10n 200n 6000n)

* For a light pulse, 1-50k lux = 11.4fA-0.57nA
ILIGHT PD VSS PULSE(0 11.4fA 500n 10n 10n 5000n 6000n)

* Wire capacitance, adc capacitance, and resistor leakage
C_COL COL VSS 20f
C_ADC COL ADC 200f
R_LEAK COL VSS 500Meg

* simulation
.tran 1000n 96u uic

.control
run
plot V(PD) V(COL) V(RESET) V(SEL) V(OUT)
.endc

.end

