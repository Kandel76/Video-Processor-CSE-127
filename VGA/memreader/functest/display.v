`timescale 1ns / 1ps

`include "../mem2vga.v"
`include "../sync_manager.v"
`include "../axi_manager.v"

module display(
    input wire clk, reset,
    /* verilator lint_off UNUSED */
    input wire up, down, left, right,
    /* verilator lint_on UNUSED */
    output wire h_sync, v_sync,
    output wire [2:0] rgb
);

    // assuming our main clk is 50MHz,
    // as its common between most of FPGA boards
    reg clk_25;
    always @(posedge clk) begin
        clk_25 <= ~clk_25;
    end

    /* verilator lint_off UNUSED */
    wire [7:0] pixel;
    /* verilator lint_on UNUSED */

    //instantiate mem2vga
    mem2vga vga_controller_unit(
        .clk(clk_25),
        .reset(reset),
        .hsync_o(h_sync),
        .vsync_o(v_sync),
        .pixel_o(pixel)
    );

    //convert pixel values to pure RGB
    logic [2:0] RGB;
    assign rgb = {RGB[0], RGB[1], RGB[2]};
    always @(*) begin
        RGB = 3'b000;
        if (pixel >= 64) RGB[0] = 1'b1;
        if (pixel >= 128) RGB[1] = 1'b1;
        if (pixel >= 192) RGB[2] = 1'b1;
    end

endmodule
