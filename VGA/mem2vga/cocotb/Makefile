# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

#enable waveform generation
WAVES ?= 1

VERILOG_SOURCES += $(PWD)/../mem2vga.v
VERILOG_SOURCES += $(PWD)/../sync_manager.v

# name of the toplevel module being tested
COCOTB_TOPLEVEL = mem2vga

# basename of the Python test file
COCOTB_TEST_MODULES = test_mem2vga

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

view : sim_build/mem2vga.fst
	gtkwave sim_build/mem2vga.fst

