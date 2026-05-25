SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES ?= 1

# RTL sources (image sensor backend)
VERILOG_SOURCES += $(PWD)/top.sv
VERILOG_SOURCES += $(PWD)/../ramp_controller.sv
VERILOG_SOURCES += $(PWD)/../sar_adc.sv
VERILOG_SOURCES += $(PWD)/../Scanner/scanner.sv
VERILOG_SOURCES += $(PWD)/../Scanner2Mem/scanner_to_mem.sv
VERILOG_SOURCES += $(PWD)/../PWM/pwm.sv

# VGA sources
VERILOG_SOURCES += $(PWD)/../../VGA/mem2vga/mem2vga.v
VERILOG_SOURCES += $(PWD)/../../VGA/mem2vga/sync_manager.v
VERILOG_SOURCES += $(PWD)/../../VGA/mem2vga/double_buffer.v
VERILOG_SOURCES += $(PWD)/../../VGA/onchipmem/gf180mcu_ocd_ip_sram__sram256x8m8wm1.v
VERILOG_SOURCES += $(PWD)/../../VGA/hitachimem/hmem_access.v

TOPLEVEL = top
COCOTB_TEST_MODULES = test_full_system

include $(shell cocotb-config --makefiles)/Makefile.sim

view: sim_build/top.fst
	gtkwave sim_build/top.fst
