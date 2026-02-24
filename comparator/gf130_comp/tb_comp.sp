* tb_comp_3v3.sp
.option compatibility=spectre
.option nomod
.option plotwinsize=0

* 1. Parameters and Globals
.param VDDVAL=3.3
.global vdd vss

* This was added by LLM because I was running into an error about using the "$" and "var_vth" errors.
.param mc_pr_switch=0
.param mc_as_switch=0

* 2. Library and Model setup
* Using .lib for the main model file to set the corner
.lib "/Users/batman/.ciel/ciel/gf180mcu/versions/54435919abffb937387ec956209f9cf5fd2dfbee/gf180mcuC/libs.tech/ngspice/sm141064.ngspice" typical

* Include the design-specific constants
.include "/Users/batman/.ciel/ciel/gf180mcu/versions/54435919abffb937387ec956209f9cf5fd2dfbee/gf180mcuC/libs.tech/ngspice/design.ngspice"

* Include the Standard Cell Library (The Inverter/Gates)
.include "/Users/batman/.ciel/ciel/gf180mcu/versions/54435919abffb937387ec956209f9cf5fd2dfbee/gf180mcuC/libs.ref/gf180mcu_fd_sc_mcu7t5v0/spice/gf180mcu_fd_sc_mcu7t5v0.spice"

* 3. Include the gf180 comparator
.include "comp_gf180.sp"

* 4. Standard Stimulus
VDD vdd 0 DC {VDDVAL}
VSS vss 0 DC 0

* 5. Inputs
* Advanced Stimulus, I have set inverting input to be a threshold of 2.5V
* Inverting input reference (threshold)
VVIM vinm 0 DC 1.65

* To test the threshold at 2.5V, use:
* VVIM vinm 0 DC 2.5

* V(vinp) tests multiple levels across the 2.5V threshold, this is the "near miss" check
* Time (ns): 0    10   10.1   20   20.1   30   
* Volt (V): 1.0  1.0   1.55   1.55  1.75  1.75
VVIP vinp 0 PWL(0 1.0 10n 1.0 10.1n 1.55 20n 1.55 20.1n 1.75 30n 1.75)

* Keep the same 10ns Clock (6 cycles total)
VCLK clk 0 PULSE(0 {VDDVAL} 1n 50p 50p 5n 10n)

* 5. Device under test
XU vinp vinm clk q qb vdd vss comp

* 6. Control Block

* This is "transient analysis", the simulation runs for 60 ns, and calculates the voltage every 10 ps
.tran 10p 60n

.control
  run
  
  * wrdata creates a text file for python script to parse
  wrdata tb_results.txt v(clk) v(vinp) v(vinm) v(q) v(qb)
  
  * message to terminal
  echo "Data exported to tb_results.txt"
  quit
  
.endc

.end