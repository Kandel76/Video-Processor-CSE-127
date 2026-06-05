module hmem_access (
    input [0:0] clk,
    input [0:0] reset,

    //write interface
    // input [0:0] wvalid_i,
    input [15:0] waddr_i, //320*240 = 76800 pixels. 2 pixels per address -> 38400 addresses. clog2 -> 16 address bits
    input [7:0] wdata_i,
    input [0:0] wvalid_i,
    output [0:0] wready_o,

    //read interface
    //input [7:0] rready_i, //ommitting ready because it should always be 1
    input [15:0] raddr_i,
    output [0:0] rvalid_o,
    output [7:0] rdata_o,

    //memory side
    //need two memory chips, control with CS
    output [14:0] addr_o,   // each chip only has 15 address bits
    output [0:0] nCS1_o,    // top (16th) bit of address
    output [0:0] nCS2_o,    // !(CS1)
    output [0:0] nOE,       // output enable. same for both chips
    output [0:0] nWE,       // write enable.  same for both chips

    output [7:0] data_o,
    input [7:0] data_i
);

    //declarations ============================================================
    logic [0:0] reading_l;
    logic [1:0] cyc3_l; //increment every cycle 00->01->10->00
    wire [0:0] writing_w;
    wire [0:0] reading_w;
    wire [0:0] flipping_w; //cycle before switching from read to write

    wire [15:0] active_address;

    logic [0:0] rvalid_r, wvalid_r;
    logic [16:0] raddr_r, waddr_r;
    logic [7:0] wdata_r, rdata_r;

    // assigning outputs ======================================================
    //external mem
    assign active_address = reading_w ? raddr_r : waddr_r;
    assign addr_o = active_address[14:0];
    assign nCS1_o = ~(~(active_address[15]) | reset);
    assign nCS2_o = ~( active_address[15]   | reset);

    assign data_o = wdata_r;
    assign nOE = ~(reading_w);
    assign nWE = ~(writing_w);

    //reader side
    assign rvalid_o = rvalid_r;
    assign rdata_o  = rdata_r;

    //writer side
    assign wready_o = flipping_w & reading_w;

    // determine whether we're reading or writing =============================
    // alternate every 3 cycles
    assign reading_w = reading_l;
    //assign writing_w = (~reading_l) & ~reset;
    assign writing_w = ~(reading_l | reset) & (wvalid_r); //write iff not a reading or reset cycle and wvalid was 1
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
    always @(posedge clk) begin
        if (reset) begin
            waddr_r <= 0;
            wdata_r <= 0;
            wvalid_r <= 0;
            raddr_r <= 0;
            rdata_r <= 0;
            rvalid_r <= 1'b0;
        end else if (flipping_w) begin
            if (reading_w) begin //ending a read cycle
                rvalid_r <= 1'b1;
                rdata_r <= data_i;
                waddr_r <= waddr_i;
                wdata_r <= wdata_i;
                wvalid_r <= wvalid_i;
            end else begin //ending a write cycle
                rvalid_r <= 1'b0;
                raddr_r <= raddr_i;
            end
        end     
    end


endmodule
