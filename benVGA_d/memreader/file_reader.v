module file_reader (
    input clk,
    input reset,
    input [18:0] addr_i,
    output [7:0] pixel_o
);
    assign pixel_o = 8'hfa;

endmodule
