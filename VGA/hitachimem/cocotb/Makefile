# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

#enable waveform generation
WAVES ?= 1

VERILOG_SOURCES += $(PWD)/../hmem_access.v

# name of the toplevel module being tested
COCOTB_TOPLEVEL = hmem_access

# basename of the Python test file
COCOTB_TEST_MODULES = test_hmem

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

