*comparator.sp
.subckt comparator CLK CLK2 INP INN AV33 AVSS COP CON

*A comparator (at least in analog) requires the following
*Differential pair
*Common source node
*clocked latch,
*NMOS and PMOS latches

*Below are internal nodes (wires I suppose if we think in verilog)
*DIP, DIN : Differential pair (dip for positive, din for negative)

*This is Differential pair (compares two voltage sources, one from DAC one from the photodiode)
*Whichever is greater will ultimately cause a 1 or 0 to be outputted by comparator, which will be used by the sar adc (hopefully)
M1 DIP INN TAIL AVSS nfet_03v3 L=0.4u W=10u
M2 DIN INP TAIL AVSS nfet_03v3 L=0.4u W=10u

*This is the common source node (tail), if our clock is off, we aren't sampling the tail is off, we can't pass anything to our Differential pair
M3 TAIL CLK AVSS AVSS nfet_03v3 L=0.4u W=4u

*These two ensure when the clk is off both of our inputs share the same voltage, so we have no misfires when idle.
M4 DIP CLK AV33 AV33 pfet_03v3 L=0.4u W=2u
M5 DIN CLK AV33 AV33 pfet_03v3 L=0.4u W=2u

*NMOS latch, ensures when one voltage is stronger than the other, it forces the weaker one to basically 0
M6 CON DIP AVSS AVSS nfet_03v3 L=0.4u W=4u
M7 COP DIN AVSS AVSS nfet_03v3 L=0.4u W=4u
M8 COP CON AVSS AVSS nfet_03v3 L=0.4u W=4u
M9 CON COP AVSS AVSS nfet_03v3 L=0.4u W=4u

*Clocked Latch, this reduces power consumption, clk2 will be 1 when idle, and 0 when we evaluate, the opposite of our clk
M10 VDD_LATCH CLK2 AV33 AV33 pfet_03v3 L=0.4u W=10u

*PMOS Latch, same as NMOS LATCH, should note that nmos and pmos latches together are essentially two inverters in a loop
M11 CON COP VDD_LATCH AV33 pfet_03v3 L=0.4u W=5u
M12 COP CON VDD_LATCH AV33 pfet_03v3 L=0.4u W=5u

.ends comparator