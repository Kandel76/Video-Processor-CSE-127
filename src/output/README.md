# mem2vga

The full path from the external memory connections to the VGA output connections.

This includes double buffering using the 3v3 on-chip SRAM made by tim edwards

The cocotb folder includes a test which generates a bmp image file from the VGA outputs of the module.

Known issues:
- bmp files read their pixel data from bottom to top, so the output image will be flipped upside down. Future plans are to update the python code to flip this.
- full-scale simulation with python will be extremely memory intensive, requiring the storage of all of the individual pixel bits in a single python file

# hmem_access

This is an RTL interface for the off-chip memory chip we are using, the HITACHI HM62256LP-70

Documentation: https://www.jameco.com/Jameco/Products/ProdDS/82472.pdf

Known limitations:
- NO same-cycle read from write
- maximal throughput of 8 bits every 6 cycles
