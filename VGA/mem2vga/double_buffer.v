module double_buffer (
    input [0:0] clk,
    input [0:0] reset,

    //current pixel state
    input [16:0] big_pix_addr,
    input [0:0] newline,
    input [0:0] endline,
    input [0:0] active_area,
    input [9:0] xpos,

    //memory side
    input [7:0] mem_rdata,
    input [0:0] mem_rvalid,
    output [15:0] mem_raddr,

    //output side
    output logic [3:0] buf_data_o //need to be buffered outside
);

    // declarations
    wire [0:0] buf1_cen_w, buf2_cen_w;
    logic [0:0] buf1_gwen_w, buf2_gwen_w;
    logic [7:0] buf1_wen_w, buf2_wen_w;
    logic [7:0] buf1_addr_w, buf2_addr_w;
    logic [7:0] buf1_wdata_w, buf2_wdata_w;
    logic [7:0] buf1_rdata_w, buf2_rdata_w;
    wire [15:0] pix_mem_w;
    wire [0:0] valid_e;
    logic [2:0] count_six, count_six_n;
    logic [0:0] sixth_l, sixth_n;
    logic [0:0] rvalid_prev;
    logic [7:0] wbuf_addr_r, wbuf_addr_n;
    logic [15:0] mem_raddr_r, mem_raddr_n; //memory address
    logic [7:0] rbuf_data;       //data from sram
    wire [7:0] rbuf_addr;       //address for sram
    wire [0:0] rbuf_read_next;  //tell sram to read
    wire [0:0] rbuf_top;        //use top bits
    logic [7:0] rbuf_buf_r; //buffer memory output
    logic [3:0] rdata_l;
    logic [0:0] row_switcher;

    assign buf1_cen_w = reset;
    assign buf2_cen_w = reset;

    // ==================================================================================
    //                               READING FROM MEMORY
    // ==================================================================================
    // Issues a read address to external memory every six cycles
    // Buffers external memory data before writing it to the buffer

    // Wire assignments =======================================================
    assign pix_mem_w = big_pix_addr[16:1]; //address for external memory

    // 6 cycle logic ==========================================================

    always @(posedge clk) begin //create registers
        if (reset || newline) begin
            sixth_l <= 0;
            count_six <= 0;
        end else begin
            sixth_l <= sixth_n;
            count_six <= count_six_n;
        end
    end

    always @(*) begin //count six loops from 0->5
        if (count_six == 5) begin
            count_six_n = 0;
        end else begin
            count_six_n = count_six + 1;
        end
    end

    always @(*) begin //sixth is high while count_six is 5; every *sixth* cycle
        if (count_six_n == 5) begin //only during active area
            sixth_n = 1;
        end else begin
            sixth_n = 0;
        end
    end

    // Buffer addressing logic ================================================
    //need to increment only after recieving valid data
    always @(posedge clk) begin
        if (reset) begin
            rvalid_prev <= 0;
        end else begin
            rvalid_prev <= mem_rvalid;
        end
    end
    assign valid_e = mem_rvalid && ~(rvalid_prev);

    always @(posedge clk) begin
        if (reset || newline) begin
            wbuf_addr_r <= 0;
        end else begin
            wbuf_addr_r <= wbuf_addr_n;
        end
    end

    always @(*) begin //increment memory after each read
        if (sixth_l && (wbuf_addr_r < 160)) begin
            wbuf_addr_n = wbuf_addr_r + 1;
        end else begin
            wbuf_addr_n = wbuf_addr_r;
        end
    end

    // Memory addressing logic ================================================
    assign mem_raddr = mem_raddr_r;

    always @(posedge clk) begin
        if (reset) begin
            mem_raddr_r <= 0;
        end else begin
            mem_raddr_r <= mem_raddr_n;
        end
    end

    always @(*) begin
        if (newline) begin
            mem_raddr_n = pix_mem_w + 16'd163;
            //added an extra 3 to account for buffers on the data path
        end else if (sixth_l && (wbuf_addr_r < 160)) begin
            mem_raddr_n = mem_raddr_r + 1;
        end else begin
            mem_raddr_n = mem_raddr_r;
        end
    end

    // ==================================================================================
    //                                  OUTPUT TO VGA
    // ==================================================================================
    // create 4-bit output for the VGA

    assign rbuf_addr = xpos[9:2]; //increment address every 4 cycles
    assign rbuf_read_next = xpos[1] && xpos[0]; //every 4th cycle. d799 ends in b11;
    assign rbuf_top = (xpos[1] ^ xpos[0]); //x = 3,4... 7,8
    // assign rbuf_top = (~xpos[1]);

    // always @(posedge clk) begin
    //     if (reset) begin
    //         rbuf_buf_r <= 0;
    //     end else if (rbuf_read_next) begin
    //         rbuf_buf_r <= rbuf_data;
    //     end
    // end
    // assign buf_data_o = rdata_l;

    //alternate top and bottom 4 bits
    always @(*) begin
        if (rbuf_top) begin
            buf_data_o = rbuf_data[7:4];
        end else begin
            buf_data_o = rbuf_data[3:0];
        end
    end
    // need to change this to do buffering outside of this module.
    // planning to have every output pin be passed out of a DFF to make timing easier (?)
    // (may need to ask ethan about that one)
    

    // ==================================================================================
    //                                MUX BETWEEN SRAMS
    // ==================================================================================
    //mux between which buffer is being read into and out of

    always @(posedge clk) begin
        if (reset) begin
            row_switcher <= 0;
        end else if (endline) begin
            row_switcher <= ~row_switcher;
        end
    end

    always @(*) begin
        if (row_switcher) begin
            // if odd  row, read buf 2 write buf 1
            buf1_addr_w = wbuf_addr_r;
            buf1_gwen_w = 0;
            buf1_wen_w = {8{sixth_l && (wbuf_addr_r < 160)}};
            buf1_wdata_w = mem_rdata;

            buf2_addr_w = rbuf_addr;
            buf2_gwen_w = 1;
            buf2_wen_w = 8'hff; //shouldn't matter
            buf2_wdata_w = 8'h00; //also shouldn't matter
            rbuf_data = buf2_rdata_w;
        end else begin
            // if even row, read buf 1 write buf 2
            buf2_addr_w = wbuf_addr_r;
            buf2_gwen_w = 0;
            buf2_wen_w = {8{sixth_l && (wbuf_addr_r < 160)}};
            buf2_wdata_w = mem_rdata;

            buf1_addr_w = rbuf_addr;
            buf1_gwen_w = 1;
            buf1_wen_w = 8'hff; //shouldn't matter
            buf1_wdata_w = 8'h00; //also shouldn't matter
            rbuf_data = buf1_rdata_w;
        end
    end
    
    //instantiate on-chip memory modules ======================================
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