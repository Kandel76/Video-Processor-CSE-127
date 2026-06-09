# Vidiode
An ASIC design for an on-chip image sensor using the gf180mcu fabrication process, designed for tapeout via wafer.space.

# Design Specifications
This repository will create a layout for an array of 320x240 photodiodes which can function as an on-chip grayscale camera. 
The analog output of these photodiodes is converted to digital signals and then output via a VGA connection. 

Use of this repository requires `CMake`, as well as `cocotb`, `iverilog`, and `python3.12`

# Makefile
The root of this repository contains a Makefile which can be used to execute the librelane synthesis flow on our design to create a complete chip layout. 
The Makefile also contains targets for both logical and gate-level synthesis.

To build the project locally, you should first run `make clone-pdk` and `make install-3v3-scl` to install the necessary libraries for the build. 
Then, you can run `make librelane` to create a Run directory. 
This process can take multiple hours, and requires at least 16 GB of local RAM.

A basic version of the local run can be performed through Github actions.

# File Structure

### src
The src directory contains all of the necessary Verilog and SystemVerilog files for the project.

### verification
The verification directory contains all of the testbenches which are needed for both the unit tests and system tests for this repository. 
We used a mix of cocotb (python) and spice simulation to test the mixed analog and digital components of our system.

### libs
The libs directory contains submodules for the pre-hardened components used by this design. Notably, this design is intended for 3.3V power, hence the 3v3 libraries. 

### ip, scripts, librelane
These directories contain several files which are necessary for librelane, the process we use to generate the chip layout.

# Architecture
This chip uses a 3v3 architecture with a 25 MHz (40 ns) clock (needed for ideal VGA output timings).

Below is a basic block diagram for the architecture of this project. 
The main data path, through which the actual pixel values are passed, is highlighted in red. 
The blocks are also color-coordinated based on where their source files are located. 
Red blocks are from the `/src/ADC` directory, green blocks are from `/src/Scanning` directory, and blue blocks are from the `/src/output` directory. 
The Photodiode array is specified in the `/ip/photodiode` directory.
Off-chip components are outlined in dotted white.

![alt text](https://github.com/Kandel76/Video-Processor-CSE-127/raw/main/docs/block_diagram.svg "Block diagram")

## Photodiodes
45% of the chip area is covered by a grid of 321x240 photodiodes.
The rightmost column of these photodiodes is not used for image detection, but the remaining 320x240 array corresponds directly to 320x240 pixels of VGA output (25% max VGA resolution). 
This resolution limit is imposed by the physical restrictions of the chip, as a larger array would not leave enough room for the other stages of the data path.

The Photodiodes are accessed in row-wise order, being controlled by the Scan Controller. 
Each row of 321 photodiodes is read simultaneously, with its output being fed into an ADC associated with a column. 
The rightmost photodiode is used to estimate the "dark current" of the array and is covered by a layer of photoresist, preventing it from actually sensing light. 
Knowing this dark current, we can estimate the maximal voltage difference expected across each diode and can thus compute subsequent brightness values based on this threshold.

## Analog to Digital Converters (ADCs)
Analog-to-Digital Conversion is performed via an array of 321 ramp ADCs. 
The analog reading from the array is compared against an analog approximation generated via a Pulse With Modulator. 
Each clock cycle, the analog approximation will increase in value, cycling through a set of 16 values. 
These 16 values correspond to a set of 4-bit digital values.
Once a column's comparator shows that the analog approximation exceeds the value of the analog reading, the associated digital value is stored and transmitted to other parts of the chip.

## Scan Controller
The scan controller acts as the central "brain" of the chip, controlling reads from the photodiode array and writes into the memory interface.

## Memory/VGA Interface
The chip uses two off-chip SRAM caches.
Off-chip memory was chosen because there simply was not a way to store the necessary data for an image on-chip, even with our reduced resolution.
For the off-chip memory, we chose the [HM6225FP-8T](https://www.jameco.com/Jameco/Products/ProdDS/82472.pdf) 32678-word x 8-bit High Speed (85ns) CMOS Static RAM.

Most of the decisions made for the Memory Interface were based on these specifications. 
The 85 ns access time is much slower than our 40 ns clock period, meaning that we could only perform a read or write every 3 clock cycles.
Working around this restriction required some manipulation of the addressing system we used, as well as some buffering.

### Addressing
In order to organize the values of each pixel that we read out, we assigned each pixel a 17-bit address. 
However, the memories we use have a data width of 8 bits, while each pixel value is only 4 bits.
Thus, we were able to package each pixel together with one neighbor. This still leaves us with 38,400 packets of 8-bit data, which is too many even for one of our off-chip SRAMs.

To fix this, the off-chip memory is accessed using the middle 15 bits [15:1] of the pixel address [16:0]. 
The bottom bit is used to determine whether a pixel value is in the top 4 bits or bottom 4 bits of that memory address, while the top bit is used to select between the two off-chip memories.

### Buffering
Proper VGA output requires that we output one pixel of data every 40 ns clock cycle.
Because we are operating at 25% VGA resolution, this requirement is more lenient, but only by 50%.
Every other cycle, the VGA output scans to a new pixel.

To account for the slow read/write time of the chip while maintaining the once-every-other-cycle outputs necessary for the VGA connection, data is buffered after being read from the off-chip memory.
Every 6 clock cycles, one 8-bit packet of pixel data is read from the off-chip memory and loaded into one of two on-chip SRAMs.
The on-chip SRAM will store one 320-pixel row of data.
Because each of our photodiode pixels is actually 2 VGA pixels "tall", the on-chip buffer is then read twice to VGA output, the other buffer is written to with the following row of pixel data.
This double-buffering allows us to comfortably reach the necessary output speed even with the slow memory read/write time.