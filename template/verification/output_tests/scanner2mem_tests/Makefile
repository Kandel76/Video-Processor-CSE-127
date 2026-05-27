TOP  = scanner2mem_tb
SRCS = scanner.sv scanner_to_mem.sv scanner_test_top.sv scanner2mem_tb.sv
OUT  = scanner2mem_tb.out
VCD  = scanner2mem_tb.vcd

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

all: run

compile:
	$(IVERILOG) -g2012 -o $(OUT) $(SRCS)

run: compile
	$(VVP) $(OUT)

wave: run
	$(GTKWAVE) $(VCD) &

clean:
	rm -f $(OUT) $(VCD)

.PHONY: all compile run wave clean
