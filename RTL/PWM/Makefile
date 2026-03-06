
TOP     = pwm_tb
SRC     = pwm.sv pwm_testbench.v
OUT     = sim.out
VCD     = pwm_waveform.vcd

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

FORMAT  = clang-format -i
LINTER = verilator


all: run


compile:
	$(IVERILOG) -g2012 -o $(OUT) $(SRC)

run: compile
	$(VVP) $(OUT)

lint:
	verilator --lint-only --timing --sv $(SRC)

format:
	@echo "Formatting sources: $(SRC)"
	$(FORMAT) $(SRC)

wave: run
	$(GTKWAVE) $(VCD)

clean:
	rm -f $(OUT) $(VCD)
