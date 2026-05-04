// SPDX-FileCopyrightText: © 2025 XXX Authors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

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

    logic [NUM_BIDIR_PADS-1:0] count;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            count <= '0;
        end else begin
            if (&input_in) begin
                count <= count + 1;
            end
        end
    end

    //VGA interface wires
    wire [0:0] hsync_o, vsync_o;
    wire [11:0] pixel_o;
    assign bidir_out[0] = hsync_o;
    assign bidir_out[1] = vsync_o;
    assign bidir_out[13:2] = pixel_o;

    //write interface wires
    //these are currently unused, so I will be using dont_touch. I'm not sure if this is good practice.
    //we'll see if this is the correct way to use this, Verilog's documentation is a bit unclear.
    (* dont_touch = "yes" *) wire [15:0] waddr_i;
    (* dont_touch = "yes" *) wire [7:0] wdata_i;
    (* dont_touch = "yes" *) wire [0:0] wvalid_i;
    (* dont_touch = "yes" *) wire [0:0] wready_o;
    assign waddr_i = 0;
    assign wdata_i = 0;
    assign wvalid_i = 0;

    //memory interface wires
    wire [14:0] addr_o;
    wire [0:0] nCS1_o;
    wire [0:0] nCS2_o;
    wire [0:0] nOE_o;
    wire [0:0] nWE_o;
    assign bidir_out[28:14] = addr_o;
    assign bidir_out[29] = nCS1_o;
    assign bidir_out[30] = nCS2_o;
    assign bidir_out[31] = nOE_o;
    assign bidir_out[32] = nWE_o;
    wire [7:0] data_o;
    wire [7:0] data_i;
    assign bidir_out[40:33] = data_o;
    assign data_i = bidir_in[40:33];

    mem2vga mymem2vga (
        .clk(clk),
        .reset(~rst_n),

        //VGA interface
        .hsync_o(hsync_o),
        .vsync_o(vsync_o),
        .pixel_o(pixel_o),  //12 bits

        //write interface
        .waddr_i(waddr_i),  //16 bits
        .wdata_i(wdata_i),  //8 bits
        .wvalid_i(wvalid_i),
        .wready_o(wready_o),

        //memory interface
        .addr_o(addr_o),    //15 bits
        .nCS1_o(nCS1_o),
        .nCS2_o(nCS2_o),
        .nOE_o(nOE_o),
        .nWE_o(nWE_o),

        .data_o(data_o),    //8 bits
        .data_i(data_i)     //8 bits. Only input pins other than clk and reset
    );




endmodule

`default_nettype wire
