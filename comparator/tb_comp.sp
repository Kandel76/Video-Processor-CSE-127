.option post
.temp 25
.param VDDVAL=1.8
VDD vdd 0 {VDDVAL}

.lib "/Users/batman/.ciel/ciel/sky130/versions/54435919abffb937387ec956209f9cf5fd2dfbee/sky130A/libs.tech/ngspice/sky130.lib.spice" tt
.include "/Users/batman/.ciel/ciel/sky130/versions/54435919abffb937387ec956209f9cf5fd2dfbee/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice"
.include "comp.sp"

* clock
VCLK clk 0 PULSE(0 {VDDVAL} 2n 50p 50p 5n 10n)

* start with obvious differential (later you can do mV steps)
VVIP vinp 0 0
VVIM vinm 0 1.8

* small caps (optional)
CinP vinp 0 50f
CinM vinm 0 50f

XU vinp vinm clk q qb vdd 0 comp

* Break symmetry at startup
.ic v(q)=0 v(qb)=1.8

Cq  q  0 5f
Cqb qb 0 5f

.tran 10p 60n

.meas tran q_max  MAX v(q)
.meas tran q_min  MIN v(q)
.meas tran qb_max MAX v(qb)
.meas tran qb_min MIN v(qb)

.meas tran tclk_q_r  TRIG v(clk) VAL=0.9 RISE=1  TARG v(q) VAL=0.9  RISE=1  FROM=2n
.meas tran tclk_q_80 TRIG v(clk) VAL=0.9 RISE=1  TARG v(q) VAL=1.44 RISE=1  FROM=2n

.control
run
wrdata comp_waves.txt v(clk) v(xu.clkb) v(q) v(qb) v(xu.n_top) v(xu.n_mid) v(xu.p_mid) v(xu.p_bot)
quit
.endc

.end
