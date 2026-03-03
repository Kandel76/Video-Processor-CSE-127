module mem2vga 
    (
    input clk, //25 MHz
    input reset,
    // debug
    output active_o,

    // VGA Interface
    output hsync_o, 
    output vsync_o,
    output [11:0] pixel_o //12 bit RGB value
    );

    // Declarations =================================================
    wire active_area; //indicates whether currently in active area
    wire [9:0] xpos, ypos;
    wire [3:0] brightness_w;

    logic [15:0] pix_addr; //pixel address

    // Debug assignments ============================================
    // This should be empty in the final versions
    assign brightness_w = 4'hf;
    assign active_o = active_area;

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