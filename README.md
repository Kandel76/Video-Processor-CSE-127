# Vidiode
An ASIC design for an on-chip image sensor using the gf180mcu fabrication process, designed for tapeout via wafer.space.

# Design Specifications
This repository will create a layout for an array of 320x240 photodiodes which can function as an on-chip grayscale camera. 
The analog output of these photodiodes is converted to digital signals via an array of 320 Successive Approximation Registers. 
This digital data is then passed into several large memories, where it is buffered before being output as VGA data.

# Repository Organization
The root of this repository contains a Makefile which can be used to execute the librelane synthesis flow on our design to create a complete chip layout. The Makefile also contains targets for both logical and gate-level synthesis.