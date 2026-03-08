module double_buffer (
    input [0:0] clk,
    input [0:0] reset,

    //memory side
    input [7:0] mem_rdata,
    input [0:0] mem_rvalid,
    output [15:0] mem_raddr,

    //current pixel state
    input [16:0] big_pix_addr,
    input odd_row_w,

    //output side
    output [3:0] buf_data_o //need a second buffer stage to give 4 bit values
)

    // wires
    logic [0:0] buf1_cen_w, buf2_cen_w;
    logic [0:0] buf1_gwen_w, buf2_gwen_w;
    logic [7:0] buf1_wen_w, buf2_wen_w;
    logic [7:0] buf1_addr_w, buf2_addr_w;
    logic [7:0] buf1_wdata_w, buf2_wdata_w;
    logic [7:0] buf1_rdata_w, buf2_rdata_w;

    logic [8:0] buf_raddr_r;


    //mux between which buffer is being read into and out of
    // TODO need to rework a lot of this XXXXXXXXXXXXXXXXXXXXXXXXX
    always @(*) begin
        if (odd_row_w) begin
            // if odd  row, read buf 2 write buf 1
            buf1_addr_w = mem_raddr_i;
            buf1_gwen_w = 0;
            buf1_wen_w = {8{~mem_rvalid_o}};
            buf1_wdata_w = mem_rdata_o;

            buf2_gwen_w = 1;
            buf2_wen_w = 8'hff;
            buf2_wdata_w = 8'h00;
            buf2_addr_w = big_pix_addr; // TODO, need to change this to buff_addr
        end else begin
            // if even row, read buf 1 write buf 2
            buf2_addr_w = mem_raddr_i;
            buf2_gwen_w = 0;
            buf2_wen_w = {8{~mem_rvalid_o}};
            buf2_wdata_w = mem_rdata_o;

            buf1_gwen_w = 1;
            buf1_wen_w = 8'hff; //w values shouldn't matter
            buf1_wdata_w = 8'h00;
            buf1_addr_w = big_pix_addr;
        end
    end
    
    //instantiate on-chip memory module s
    gf180mcu_ocd_ip_sram__sram256x8m8wm1 buf1(
        .CLK(clk),
        .CEN(buf1_cen_w),
        .GWEN(buf1_gwen_w),
        .WEN(buf1_wen_w), //8 bits
        .A(buf1_addr_w), //8 bits
        .D(buf1_wdata_w), //8 bits
        .Q(buf1_rdata_w) //8 bits
    );
    gf180mcu_ocd_ip_sram__sram256x8m8wm1 buf2(
        .CLK(clk),
        .CEN(buf2_cen_w),
        .GWEN(buf2_gwen_w),
        .WEN(buf2_wen_w), //8 bits
        .A(buf2_addr_w), //8 bits
        .D(buf2_wdata_w), //8 bits
        .Q(buf2_rdata_w) //8 bits
    );

endmodule