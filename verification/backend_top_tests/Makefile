SIM = icarus
COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: sim_top sim_sar_adc sim_ramp_control

SRC := ../../src

sim_top:
	$(MAKE) clean
	$(MAKE) sim \
		TOPLEVEL=top \
		COCOTB_TEST_MODULES=test_top \
		VERILOG_SOURCES="backend_top.sv \
		                 $(SRC)/ADC/sar_adc.sv \
		                 $(SRC)/ADC/ramp_controller.sv \
		                 $(SRC)/Scanning/scanner.sv \
		                 $(SRC)/Scanning/scanner_to_mem.sv"

sim_sar_adc:
	$(MAKE) clean
	$(MAKE) sim \
		TOPLEVEL=sar_adc \
		COCOTB_TEST_MODULES=test_sar_adc \
		PYTHONPATH=../ADC_tests \
		VERILOG_SOURCES="$(SRC)/ADC/sar_adc.sv"

sim_ramp_control:
	$(MAKE) clean
	$(MAKE) sim \
		TOPLEVEL=ramp_controller \
		COCOTB_TEST_MODULES=test_ramp_control \
		PYTHONPATH=../ADC_tests \
		VERILOG_SOURCES="$(SRC)/ADC/ramp_controller.sv"