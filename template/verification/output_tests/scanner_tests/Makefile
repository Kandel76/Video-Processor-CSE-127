TOP  = scanner_tb
SRCS = ../Scanner2Mem/scanner.sv scanner_tb.sv
OUT  = scanner_tb.out
VCD  = scanner_tb.vcd

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