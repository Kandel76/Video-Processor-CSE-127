#   make all                    — gradient pattern, dark ref = 0
#   make all IMG=photo.png      — use a real image, dark ref = 0
#   make all DARK=3             — gradient pattern, dark reference = 3
#   make all IMG=photo.png DARK=5  — real image with dark reference = 5
#   make gen                    — just generate input_pixels.hex
#   make sim                    — compile + simulate (requires gen first)
#   make check                  — compare output to reference
#   make clean                  — remove all generated files

IMG  ?=   # leave empty to use the built-in gradient pattern
DARK ?= 0 # dark reference nibble (0-15); scanner subtracts this from every pixel

SV_TOP  = img_tb
SV_SRCS = img_tb.sv \
           ../Scanner/scanner.sv \
           ../Scanner2Mem/scanner_to_mem.sv

IVERILOG = iverilog
VVP      = vvp
PYTHON   = python3

.PHONY: all gen sim check clean

all: gen sim check

# Generate input hex from image (or gradient if IMG="")
gen: gen_input.py
	$(PYTHON) gen_input.py $(IMG) --dark $(DARK)

#Compile
$(SV_TOP).out: $(SV_SRCS)
	$(IVERILOG) -g2012 -Wall -Wno-timescale -o $@ $^

#Simulate (also depends on hex file being present)
sim: $(SV_TOP).out input_pixels.hex
	$(VVP) $(SV_TOP).out

# Check output against reference
check: check_output.py output_pixels.hex
	$(PYTHON) check_output.py

clean:
	rm -f $(SV_TOP).out
	rm -f input_pixels.hex input_ref.npy input_preview.png
	rm -f output_pixels.hex output_image.png diff.png
