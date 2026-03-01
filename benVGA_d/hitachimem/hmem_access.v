module hmem_access (
    input [0:0] clk,
    input [0:0] reset,

    //write interface
    input [0:0] wvalid_i,
    input [16:0] waddr_i, //320*240 = 76800 addresses -> clog2 -> 17 address bits
    input [7:0] wdata_i,
    output [0:0] wready_o,

    //read interface
    //input [7:0] rready_i, //ommitting ready because it should always be 1
    input [16:0] raddr_i,
    output [0:0] rvalid_o,
    output [7:0] rdata_o,

    //memory side
    output [16:0] raddr_o,
    input [7:0] data_i
);

    // determine whether we're reading or writing =============================
    // alternate every 3 cycles

    logic [0:0] reading_l;
    logic [1:0] cyc3_l; //increment every cycle 00->01->10->00
    wire [0:0] writing_w;
    wire [0:0] reading_w;
    wire [0:0] flipping_w; //cycle before switching from read to write

    assign reading_w = reading_l;
    assign writing_w = ~reading_l;
    assign flipping_w = cyc3_l[1];

    always @(posedge clk) begin
        if (reset) begin
            reading_l <= 0;
            cyc3_l <= 0;
        end else if (flipping_w) begin
            cyc3_l <= 0;
            reading_l <= ~reading_l;
        end else begin
            cyc3_l <= cyc3_l + 1;
        end
    end


    //buffering addresses and data ============================================

    logic [16:0] raddr_r, waddr_r;
    logic [7:0] wdata_r;

    always @(posedge clk) begin
        if (reset) begin
            raddr_r <= 0;
            waddr_r <= 0;
            wdata_r <= 0;
        end else if (flipping_w) begin
            if (writing_w) begin    // perhaps change this to reading_w
                waddr_r <= waddr_i;
                wdata_r <= wdata_i;
            end else begin
                raddr_r <= raddr_i;
            end
        end else begin
            raddr_r <= raddr_r;
            waddr_r <= waddr_r;
        end
    end

endmodule
