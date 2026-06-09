# Vidiode
An ASIC design for an on-chip image sensor using the gf180mcu fabrication process, designed for tapeout via wafer.space.

# Design Specifications
This repository will create a layout for an array of 320x240 photodiodes which can function as an on-chip grayscale camera. 
The analog output of these photodiodes is converted to digital signals via an array of 320 ramp-comparison analog-to-digital conversion. 
This digital data is then passed into several large off-chip memories, where it is buffered before being output as VGA data.

Use of this repository requires `CMake`, as well as `cocotb`, `iverilog`, and `python3.12`

# Makefile
The root of this repository contains a Makefile which can be used to execute the librelane synthesis flow on our design to create a complete chip layout. 
The Makefile also contains targets for both logical and gate-level synthesis.

To build the project locally, you should first run `make clone-pdk` and `make install-3v3-scl` to install the necessary libraries for the build. 
Then, you can run `make librelane` to create a Run directory. 
This process can take multiple hours, and requires at least 16 GB of local RAM.

A basic version of the local run can be performed through Github actions.

# File Structure

## src
The src directory contains all of the necessary Verilog and SystemVerilog files for the project.

## verification
The verification directory contains all of the testbenches which are needed for both the unit tests and system tests for this repository. 
We used a mix of cocotb (python) and spice simulation to test the mixed analog and digital components of our system.

## libs
The libs directory contains submodules for the pre-hardened components used by this design. Notably, this design is intended for 3.3V power, hence the 3v3 libraries. 

## ip, scripts, librelane
These directories contain several files which are necessary for librelane, the process we use to generate the chip layout.

# Architecture

![alt text](https://github.com/Kandel76/Video-Processor-CSE-127/raw/main/docs/block_diagram.svg "Block diagram")