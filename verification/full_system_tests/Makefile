SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES ?= 1

# Set GL_SIM=1 to run gate-level simulation.
# Requires a synthesized netlist at GL_NETLIST (module name must be 'top').
# Produce it with: make synth-gl from template/
GL_SIM ?= 0

ifeq ($(GL_SIM),1)
# ── Gate-level simulation ─────────────────────────────────────────────────────
# GL_NETLIST : synthesized netlist of full_system.sv (module: top)
# STD_CELL_LIB : Verilog functional models for gf180mcu_as_sc_mcu7t3v3
GL_NETLIST   ?= $(PWD)/gl/top_gl.v
STD_CELL_LIB ?= $(PWD)/../../gf180mcu/gf180mcuD/libs.ref/gf180mcu_as_sc_mcu7t3v3/verilog/gf180mcu_as_sc_mcu7t3v3.v

VERILOG_SOURCES += $(GL_NETLIST)
VERILOG_SOURCES += $(STD_CELL_LIB)
# SRAM behavioral model — double_buffer.v instantiates two of these as line buffers
VERILOG_SOURCES += $(PWD)/../../libs/gf180mcu_ocd_ip_sram/cells/gf180mcu_ocd_ip_sram__sram256x8m8wm1/gf180mcu_ocd_ip_sram__sram256x8m8wm1.v

# FUNCTIONAL skips timing checks in cell models; UNIT_DELAY adds 1-step gate delay
COMPILE_ARGS += -DFUNCTIONAL -DUNIT_DELAY=#1

else
# ── RTL simulation ────────────────────────────────────────────────────────────
VERILOG_SOURCES += $(PWD)/full_system.sv
VERILOG_SOURCES += $(PWD)/../../src/ADC/ramp_controller.sv
VERILOG_SOURCES += $(PWD)/../../src/ADC/sar_adc.sv
VERILOG_SOURCES += $(PWD)/../../src/Scanning/scanner.sv
VERILOG_SOURCES += $(PWD)/../../src/Scanning/scanner_to_mem.sv
VERILOG_SOURCES += $(PWD)/../../src/ADC/pwm.sv
VERILOG_SOURCES += $(PWD)/../../src/output/mem2vga.v
VERILOG_SOURCES += $(PWD)/../../src/output/sync_manager.v
VERILOG_SOURCES += $(PWD)/../../src/output/double_buffer.v
VERILOG_SOURCES += $(PWD)/../../src/output/hmem_access.v
VERILOG_SOURCES += $(PWD)/../../libs/gf180mcu_ocd_ip_sram/cells/gf180mcu_ocd_ip_sram__sram256x8m8wm1/gf180mcu_ocd_ip_sram__sram256x8m8wm1.v

endif

TOPLEVEL = top
COCOTB_TEST_MODULES = test_full_system

include $(shell cocotb-config --makefiles)/Makefile.sim

view: sim_build/top.fst
	gtkwave sim_build/top.fst
