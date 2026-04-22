// SPDX-FileCopyrightText: © 2025 XXX Authors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

`include "../../../VGA/mem2vga/mem2vga.v"

module chip_core #(
    parameter NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS
    )(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif
    
    input  wire clk,       // clock
    input  wire rst_n,     // reset (active low)
    
    input  wire [NUM_INPUT_PADS-1:0] input_in,   // Input value
    output wire [NUM_INPUT_PADS-1:0] input_pu,   // Pull-up
    output wire [NUM_INPUT_PADS-1:0] input_pd,   // Pull-down

    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,   // Input value
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,  // Output value
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,   // Output enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,   // Input type (0=CMOS Buffer, 1=Schmitt Trigger)
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,   // Slew rate (0=fast, 1=slow)
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,   // Input enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,   // Pull-up
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,   // Pull-down

    inout  wire [NUM_ANALOG_PADS-1:0] analog  // Analog
);

    // See here for usage: https://gf180mcu-pdk.readthedocs.io/en/latest/IPs/IO/gf180mcu_fd_io/digital.html
    
    // Disable pull-up and pull-down for input
    assign input_pu = '0;
    assign input_pd = '0;

    // Set the bidir as output
    assign bidir_oe = '1;
    assign bidir_cs = '0;
    assign bidir_sl = '0;
    assign bidir_ie = ~bidir_oe;
    assign bidir_pu = '0;
    assign bidir_pd = '0;
    
    logic _unused;
    assign _unused = &bidir_in;

    mem2vga mymem2vga (
        .clk(clk),
        .reset(~rst_n),

        // VGA Interface
        .hsync_o(bidir_out[0]), 
        .vsync_o(bidir_out[1]),
        .pixel_o(bidir_out[13:2]), // 12 bit RGB value

        // // write interface
        // input [15:0] waddr_i,   // 320*240 = 76800 pixels. 
        //                         // 2 pixels per address -> 38400 addresses
        //                         // clog2 -> 16 address bits
        // input [7:0] wdata_i,
        // .[0:0] wready_o,

        //memory interface
        .addr_o(bidir_out[27:14]),   // each chip only has 15 address bits
        .nCS1_o(bidir_out[28]),    // top (16th) bit of address
        .nCS2_o(bidir_out[29]),    // !(CS1)
        .nOE_o(bidir_out[30]),       // output enable. same for both chips
        .nWE_o(bidir_out[31]),       // write enable.  same for both chips

        .data_o(bidir_out[39:32]),
        .data_i(input_in[7:0])
    )


endmodule

`default_nettype wire
