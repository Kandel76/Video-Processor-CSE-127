/*verilator lint_off UNUSED*/

module axi_manager (
    input clk,
    input reset,
    input [9:0] xpos_i,
    input [9:0] ypos_i,
    input active_i,
    output [7:0] pixel_o
);

    localparam NUMPIXELS = 307200; //480 * 640
    localparam ADDRESS_WIDTH = $clog2(NUMPIXELS); //19

    logic [ADDRESS_WIDTH-1:0] addr_l;

    //temp
    localparam SIZE = 32;
    localparam ADDRESSABLE = $clog2(SIZE);
    reg [SIZE-1:0] data_r = 32'h00aaaaff;

/*verilator lint_on UNUSED*/

    
    //address simply counts up while in the active region
    always @(posedge clk) begin
        if (reset) begin
            addr_l <= 0;
        end else if (active_i) begin
            addr_l <= addr_l + 1;
        end else begin
            addr_l <= addr_l;
        end
    end

    //temp stuff
    
    //assign pixel_o = addr_l[8:1];
    assign pixel_o = addr_l;

endmodule
