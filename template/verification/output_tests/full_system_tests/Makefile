SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES ?= 1

# RTL sources (image sensor backend)
VERILOG_SOURCES += $(PWD)/full_system.sv
VERILOG_SOURCES += $(PWD)/../../../src/ADC/ramp_controller.sv
VERILOG_SOURCES += $(PWD)/../../../src/ADC/sar_adc.sv
VERILOG_SOURCES += $(PWD)/../../../src/Scanning/scanner.sv
VERILOG_SOURCES += $(PWD)/../../../src/Scanning/scanner_to_mem.sv
VERILOG_SOURCES += $(PWD)/../../../src/ADC/pwm.sv

# VGA sources
VERILOG_SOURCES += $(PWD)/../../../src/output/mem2vga.v
VERILOG_SOURCES += $(PWD)/../../../src/output/sync_manager.v
VERILOG_SOURCES += $(PWD)/../../../src/output/double_buffer.v
VERILOG_SOURCES += $(PWD)/../../../src/output/gf180mcu_ocd_ip_sram__sram256x8m8wm1.v
VERILOG_SOURCES += $(PWD)/../../../src/output/hmem_access.v

TOPLEVEL = top
COCOTB_TEST_MODULES = test_full_system

include $(shell cocotb-config --makefiles)/Makefile.sim

view: sim_build/top.fst
	gtkwave sim_build/top.fst
