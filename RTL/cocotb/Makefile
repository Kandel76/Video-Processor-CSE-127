ROWS ?= 240
COLS ?= 320
SIM = icarus

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: sim_top sim_sar_adc sim_ramp_control

sim_top:
	$(MAKE) clean
	$(MAKE) sim \
		TOPLEVEL=top \
		COCOTB_TEST_MODULES=test_top \
		VERILOG_SOURCES="../top.sv ../sar_adc.sv ../ramp_controller.sv ../Scanner/scanner.sv ../Scanner2Mem/scanner_to_mem.sv" \

sim_sar_adc:
	$(MAKE) clean
	$(MAKE) sim \
		TOPLEVEL=sar_adc \
		COCOTB_TEST_MODULES=test_sar_adc \
		VERILOG_SOURCES="../sar_adc.sv"

sim_ramp_control:
	$(MAKE) clean
	$(MAKE) sim \
		TOPLEVEL=ramp_controller \
		COCOTB_TEST_MODULES=test_ramp_control \
		VERILOG_SOURCES="../ramp_controller.sv"