module bridge (
    input btnU,
    input btnD,
    input btnC, //reset
    input btnR,
    input btnL,
    input clkin,
    input [15:0] sw,
    output dp,
    output [3:0] an,
    output [6:0] seg,
    output [15:0] led,

    output Hsync,
    output Vsync,
    output [3:0] vgaBlue,
    output [3:0] vgaGreen,
    output [3:0] vgaRed
);


    wire [7:0] pixelbus;
    assign vgaBlue  = pixelbus [3:0];
    assign vgaGreen = pixelbus [7:4];
    assign vgaRed = pixelbus[7:4] & pixelbus[3:0];
    //assign vgaBlue = 4'hf;
    //assign vgaGreen = 4'hf;
    //assign vgaRed = 4'hf;

    mem2vga actualUUT (
        .clk(clkin),
        .reset(btnC),
        .hsync_o(Hsync),
        .vsync_o(Vsync),
        .pixel_o(pixelbus)
    );

    assign dp = 0;
    assign an = 0;
    assign seg = 0;
    assign led = 0;

endmodule
