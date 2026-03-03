
TOP     = pwm_tb
SRC     = pwm.sv pwm_testbench.v
OUT     = sim.out
VCD     = pwm.vcd

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave


all: run


compile:
	$(IVERILOG) -g2012 -o $(OUT) $(SRC)


run: compile
	$(VVP) $(OUT)


wave: run
	$(GTKWAVE) $(VCD)

clean:
	rm -f $(OUT) $(VCD)
