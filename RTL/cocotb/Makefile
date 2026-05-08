# Makefile

SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES = \
	../top.sv \
	../sar_adc.sv \
	../ramp_controller.sv \
	../Scanner/scanner.sv \
	../Scanner2Mem/scanner_to_mem.sv

TOPLEVEL = top
COCOTB_TEST_MODULES = test_top

include $(shell cocotb-config --makefiles)/Makefile.sim
