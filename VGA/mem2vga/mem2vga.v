module mem2vga 
    (
    input clk, //25 MHz
    input reset,
    // debug
    output active_o,

    // Chip enable for on-chip memory
    input CEN,

    // VGA Interface
    output hsync_o, 
    output vsync_o,
    output [11:0] pixel_o, //12 bit RGB value

    //write interface
    // input [0:0] wvalid_i,
    input [15:0] waddr_i, //320*240 = 76800 pixels. 2 pixels per address -> 38400 addresses. clog2 -> 16 address bits
    input [7:0] wdata_i,
    output [0:0] wready_o,

    //memory interface
    output [14:0] addr_o,   // each chip only has 15 address bits
    output [0:0] nCS1_o,    // top (16th) bit of address
    output [0:0] nCS2_o,    // !(CS1)
    output [0:0] nOE,       // output enable. same for both chips
    output [0:0] nWE,       // write enable.  same for both chips

    output [7:0] data_o,
    input [7:0] data_i
    );


    // Declarations =================================================
    wire active_area; //indicates whether currently in active area
    wire [9:0] xpos, ypos;
    wire [3:0] brightness_w;

    //addressing
    logic [17:0] small_pix_addr;    //pixel address for VGA
    logic [15:0] big_pix_addr;      //pixel address for diodes
    logic [0:0] odd_row_w;
    wire [1:0] quadrant_w;

    //buffers
    logic [0:0] buf1_cen_w, buf2_cen_w;
    logic [0:0] buf1_gwen_w, buf2_gwen_w;
    logic [7:0] buf1_wen_w, buf2_wen_w;
    logic [7:0] buf1_addr_w, buf2_addr_w;
    logic [7:0] buf1_wdata_w, buf2_wdata_w;
    logic [7:0] buf1_rdata_w, buf2_rdata_w;

    //memory
    wire [15:0] mem_raddr_i;
    wire [7:0] mem_rdata_o;
    wire [0:0] mem_rvalid_o;

    // Debug assignments ============================================
    // This should be empty in the final versions
    //assign brightness_w = 4'h8;
    //assign brightness_w = pix_addr[15:12];
    //assign brightness_w = pix_addr[3:0];
    assign brightness_w = big_pix_addr[7:4];
    //assign brightness_w = {(xpos == 641), 3'b000};
    //assign brightness_w = {2{ypos[1:0]}};
    //assign brightness_w = {quadrant_w, 2'b00};
    assign active_o = active_area;

    // Determine pixel address ======================================

    //determine which part of pixel we're in:
    //quadrants: 0 1 // 2 3
    assign quadrant_w = {ypos[0], xpos[0]};
    assign odd_row_w = ypos[0];

    always @(posedge clk) begin
        if (reset) begin
            small_pix_addr <= 0;
            big_pix_addr <= 0;
        end else if (active_area) begin
            if (quadrant_w[0]) begin // big pixel every other pixel
                big_pix_addr <= big_pix_addr + 1;
            end
            small_pix_addr <= small_pix_addr + 1;
        end else if ((xpos == 641) & (~odd_row_w)) begin
            big_pix_addr <= big_pix_addr - 320;
        end
    end


    // Read from off-chip memory ====================================
    //instantiate memory interface
    hmem_access off_chip_mem (
        .clk(clk),
        .reset(reset),

        //write interface (directly to module output)
        .waddr_i(waddr_i),      // 16 bits
        .wdata_i(wdata_i),      // 8 bits
        .wready_o(wready_o),    // 1 bit

        //read interface
        .raddr_i(mem_raddr_i),      // 16 bits
        .rvalid_o(mem_rvalid_o),    // 1 bit
        .rdata_o(mem_rdata_o),      // 8 bits

        //memory side (goes directly to module output)
        .addr_o(addr_o),
        .nCS1_o(nCS1_o),
        .nCS2_o(nCS2_o),
        .nOE(nOE_o),
        .nWE(nWE_o),

        .data_o(data_o), // 8 bits
        .data_i(data_i)  // 8 bits
    );

    // Double Buffer ================================================
    // its own module
    
    //VGA Output ====================================================
    assign pixel_o = {3{brightness_w}};

    sync_manager syncer(
        .clk(clk),
        .reset(reset),
        .hsync_o(hsync_o),
        .vsync_o(vsync_o),
        .coord_x(xpos),
        .coord_y(ypos),
        .active_area(active_area)
    );

endmodule