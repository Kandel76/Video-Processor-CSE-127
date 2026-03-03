.lib "/home/tlaruiz/.ciel/ciel/gf180mcu/versions/54435919abffb937387ec956209f9cf5fd2dfbee/gf180mcuD/libs.tech/ngspice/design.ngspice"

*Diode Voltage
VREF vref 0 3.3


.param Rparam=1k

* resistor series chain: vref -> t15 -> ... -> t1 -> t0 -> 0 (GND)
* NOTE: These are ideal resistors, download issues, will integrate gf180 pdk hopefully soon
Rr15 vref t15 {Rparam}
Rr14 t15  t14 {Rparam}
Rr13 t14  t13 {Rparam}
Rr12 t13  t12 {Rparam}
Rr11 t12  t11 {Rparam}
Rr10 t11  t10 {Rparam}
Rr9  t10  t9  {Rparam}
Rr8  t9   t8  {Rparam}
Rr7  t8   t7  {Rparam}
Rr6  t7   t6  {Rparam}
Rr5  t6   t5  {Rparam}
Rr4  t5   t4  {Rparam}
Rr3  t4   t3  {Rparam}
Rr2  t3   t2  {Rparam}
Rr1  t2   t1  {Rparam}
Rr0  t1   t0  {Rparam}
Rend t0   0  {Rparam}

*NEXT STEPS: mux chain based on adc input code, will generate specific test voltage to be sent to comparator
.control
  op
  print v(t0) v(t1) v(t2) v(t8) v(t15)
  quit
.endc
