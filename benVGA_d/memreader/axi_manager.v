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
/*verilator lint_on UNUSED*/

    reg [7:0] pixel_r;
    assign pixel_o = pixel_r;

    //2 parallel register banks/caches
    localparam SIZE = 32;
    reg [SIZE-1:0] cache1_r, cache2_r;

    //one bit to choose between caches
    // cache1 = 0, cache2 = 1
    logic which_cache_l;
    //2 bits to address a region of the cache:
    // 76543210 | 76543210 | 76543210 | 76543210
    // 3          2          1          0
    logic [1:0] cache_region_l;

    //choose one register to write to and one register to read from
    //TODO: first tick after reset will have no input.
    always @(posedge clk) begin
        if (reset) begin
            which_cache_l <= 1'b0;
            cache_region_l <= 2'b0;
            cache1_r <= 0;
            cache2_r <= 0;
        end else if (active_i) begin
            if (which_cache_l) begin
                //reading from cache 2, writing cache 1
                //cache1_r <= 32'h01234567; //TEMP assignment for debug
                cache1_r <= {4{addr_l[7:0]}}; //TEMP assignment for debug

                //index cache
                case (cache_region_l)
                    2'h0: pixel_r <= cache2_r[7:0];
                    2'h1: pixel_r <= cache2_r[15:8];
                    2'h2: pixel_r <= cache2_r[23:16];
                    2'h3: pixel_r <= cache2_r[31:24];
                endcase
            end else begin
                //reading from cache 1, writing cache 2
                //cache2_r <= 32'hffffffff; //TEMP assignment for debug
                cache2_r <= {addr_l, 13'h1fff}; //32-19 = 13
                //$display(addr_l);

                //index cache
                case (cache_region_l)
                    2'h0: pixel_r <= cache1_r[7:0];
                    2'h1: pixel_r <= cache1_r[15:8];
                    2'h2: pixel_r <= cache1_r[23:16];
                    2'h3: pixel_r <= cache1_r[31:24];
                endcase
            end

            //update cache addressing valus
            if (cache_region_l >= 3) which_cache_l <= ~which_cache_l;
            cache_region_l <= cache_region_l + 1;
        end
    end

    
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


    //temp stuff for debug ====================================================

    //file reader module
    /*
    wire [ADDRESS_WIDTH-1:0]addr_w;
    assign addr_w = addr_l;
    file_reader fr (
        .clk(clk),
        .reset(reset),
        .addr_i(addr_w),
        .pixel_o(pixel_o)
    );*/
    
    //assign pixel_o = addr_l[17:10];

endmodule
