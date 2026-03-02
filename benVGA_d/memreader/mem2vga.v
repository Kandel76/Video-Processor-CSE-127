module mem2vga 
    (
    input clk, //25 MHz
    input reset,
    output active_o, //TODO testing purposes only
    output hsync_o, 
    output vsync_o,
    output [7:0] pixel_o //8 bit pixel brightness value
    );

    //wires
    wire active_area; //indicates whether currently in active area
    assign active_o = active_area; //TODO debug only
    wire [9:0] xpos, ypos;

    sync_manager syncer(
        .clk(clk),
        .reset(reset),
        .hsync_o(hsync_o),
        .vsync_o(vsync_o),
        .coord_x(xpos),
        .coord_y(ypos),
        .active_area(active_area)
    );

    //instantiate memory interface manager
    //(generates pixel data)
    axi_manager pixelgen(
        .clk(clk),
        .reset(reset),
        .xpos_i(xpos),
        .ypos_i(ypos),
        .active_i(active_area),
        .pixel_o(pixel_o)
    );

    /*
    logic [7:0] pixel_l;
    assign pixel_o = pixel_l;

    always @(posedge clk) begin
        if (reset) begin
            pixel_l <= 8'h00;
        end else if (active_area && (pixel_l <= 240)) begin
            pixel_l <= pixel_l + 1;
        end else if (active_area) begin
            pixel_l <= pixel_l;
        end else begin
            pixel_l <= 8'h00;
        end
    end
    */

endmodule
