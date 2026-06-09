// SPDX-FileCopyrightText: © 2025 XXX Authors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

// Requires SLOT_1X0P5: NUM_INPUT_PADS=4, NUM_BIDIR_PADS=46, NUM_ANALOG_PADS=4
//
// Input pad map:
//  [0]      pwm_clk  (100 MHz — currently unused inside top, wired for completeness)
//  [3:1]    unused
//
// Bidir pad map:
//  [0]      hsync_o
//  [1]      vsync_o
//  [13:2]   pixel_o[11:0]
//  [28:14]  mem_addr_o[14:0]
//  [29]     mem_nCS1_o
//  [30]     mem_nCS2_o
//  [31]     mem_nOE_o
//  [32]     mem_nWE_o
//  [40:33]  mem_data[7:0]   (bidir: output when writing, input when reading)
//  [41]     pwm_out
//  [45:42]  unused
//  ---------------------------------
//  FOR LATER -- ANALOG IN FOR V_REF
//  ---------------------------------

module chip_core #(
    parameter NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS
    )(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input  wire clk,       // 25 MHz main clock
    input  wire rst_n,     // reset (active low)

    input  wire [NUM_INPUT_PADS-1:0] input_in,
    output wire [NUM_INPUT_PADS-1:0] input_pu,
    output wire [NUM_INPUT_PADS-1:0] input_pd,

    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,

    inout  wire [NUM_ANALOG_PADS-1:0] analog  // unused for NOW — analog domain only
);

    // No pull-up/pull-down, CMOS buffer, fast slew on all pads
    assign input_pu = '0;
    assign input_pd = '0;
    assign bidir_cs = '0;
    assign bidir_sl = '0;
    assign bidir_pu = '0;
    assign bidir_pd = '0;

    // -----------------------------------------------------------------------
    // Input pads
    // -----------------------------------------------------------------------
    wire pwm_clk = input_in[0];

    logic _unused_inputs;
    assign _unused_inputs = &input_in[NUM_INPUT_PADS-1:1];

    // -----------------------------------------------------------------------
    // Internal wires from top
    // -----------------------------------------------------------------------
    wire        hsync_w, vsync_w;
    wire [11:0] pixel_w;
    wire [14:0] mem_addr_w;
    wire        mem_nCS1_w, mem_nCS2_w, mem_nOE_w, mem_nWE_w;
    wire [7:0]  mem_data_out_w;
    wire [7:0]  mem_data_in_w;
    wire        pwm_out_w;
    wire        rc_filter_in;

    // mem_data bus is driven out only when the write-enable is asserted
    wire mem_wr_active = ~mem_nWE_w;

    // -----------------------------------------------------------------------
    // Bidir output vector
    // -----------------------------------------------------------------------
    assign bidir_out[0]      = hsync_w;
    assign bidir_out[1]      = vsync_w;
    assign bidir_out[13:2]   = pixel_w;
    assign bidir_out[28:14]  = mem_addr_w;
    assign bidir_out[29]     = mem_nCS1_w;
    assign bidir_out[30]     = mem_nCS2_w;
    assign bidir_out[31]     = mem_nOE_w;
    assign bidir_out[32]     = mem_nWE_w;
    assign bidir_out[40:33]  = mem_data_out_w;
    assign bidir_out[41]     = pwm_out_w;

    generate
        if (NUM_BIDIR_PADS > 42)
            assign bidir_out[NUM_BIDIR_PADS-1:42] = '0;
    endgenerate

    assign rc_filter_in = analog[0];

    // -----------------------------------------------------------------------
    // Output enables  (1 = drive, 0 = high-Z / input)
    // -----------------------------------------------------------------------
    assign bidir_oe[0]      = 1'b1;
    assign bidir_oe[1]      = 1'b1;
    assign bidir_oe[13:2]   = {12{1'b1}};
    assign bidir_oe[28:14]  = {15{1'b1}};
    assign bidir_oe[29]     = 1'b1;
    assign bidir_oe[30]     = 1'b1;
    assign bidir_oe[31]     = 1'b1;
    assign bidir_oe[32]     = 1'b1;
    assign bidir_oe[40:33]  = {8{mem_wr_active}};  // high-Z when reading so memory can drive
    assign bidir_oe[41]     = 1'b1;

    generate
        if (NUM_BIDIR_PADS > 42)
            assign bidir_oe[NUM_BIDIR_PADS-1:42] = '0;
    endgenerate

    assign bidir_ie = ~bidir_oe;

    // Read memory data back from the bidir pads when not writing
    assign mem_data_in_w = bidir_in[40:33];

    // -----------------------------------------------------------------------
    // Design under test
    // cmp_o tied to '0 — comparator path not used for digital GL simulation
    // -----------------------------------------------------------------------
    top #(
        .ROWS              (240),
        .COLS              (320),
        .DATA_BITS         (4),
        .RESET_CYCLES      (10),
        .INTEGRATION_CYCLES(10),
        .RAMP_TIME         (213)
    ) u_top (
        .clk          (clk),
        .pwm_clk      (pwm_clk),
        .rst_n        (rst_n),
        `ifdef SIMULATION
        .cmp_o        ('0),
        `endif

        .hsync_o      (hsync_w),
        .vsync_o      (vsync_w),
        .pixel_o      (pixel_w),

        .mem_addr_o   (mem_addr_w),
        .mem_nCS1_o   (mem_nCS1_w),
        .mem_nCS2_o   (mem_nCS2_w),
        .mem_nOE_o    (mem_nOE_w),
        .mem_nWE_o    (mem_nWE_w),
        .mem_data_o   (mem_data_out_w),
        .mem_data_i   (mem_data_in_w),

        .rc_filter_in (rc_filter_in)
        .pwm_out      (pwm_out_w)
    );

endmodule

`default_nettype wire
