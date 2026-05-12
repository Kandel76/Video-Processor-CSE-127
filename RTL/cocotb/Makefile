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

ROWS ?= 240
COLS ?= 320

COMPILE_ARGS += -P top.ROWS=$(ROWS) -P top.COLS=$(COLS) \
                -P top.RAMP_TIME=4 -P top.RESET_CYCLES=2 -P top.INTEGRATION_CYCLES=2

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: sim_sar_adc
sim_sar_adc:
	$(MAKE) clean
	$(MAKE) sim \
	TOPLEVEL=sar_adc \
	COCOTB_TEST_MODULES=test_sar_adc \
	VERILOG_SOURCES=../sar_adc.sv
