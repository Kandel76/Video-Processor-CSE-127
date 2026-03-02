module ram_1r1w_async
#(parameter [31:0] width_p = 32,
    parameter [31:0] depth_p = 400000,
    parameter [0:0] init_p = 1,
    parameter string filename_p = "memory_init_file.bin"
)
(
    input clk_i,
    input reset_i,
    input wr_valid_i,
    input [width_p-1 : 0] wr_data_i,
    input [$clog2(depth_p)-1 : 0] wr_addr_i,
    input [$clog2(depth_p)-1 : 0] rd_addr_i,
    output [width_p-1 : 0] rd_data_o
);
   
    logic [width_p-1:0] data_w [depth_p-1:0];
   
    assign rd_data_o = data_w[rd_addr_i];
    
    initial begin
        // Display depth and width (You will need to match these in your init file)
        $display("%m: depth_p is %d, width_p is %d", depth_p, width_p);
        // wire [bar:0] foo [baz:0];
        if(init_p) begin // if init_p is 1, use readmemh. This will reduce warnings in your FIFO implementation.
            $readmemh({`HEXPATH, filename_p}, data_w, 0); //ben edited this (unsure of which parameter
        end
        // In order to get the memory contents in iverilog you need to run this for loop during initialization:
        // synopsys translate_off
        for (int i = 0; i < depth_p; i++)
            $dumpvars(0, data_w[i]);
        // synopsys translate_on
    end

    always @(posedge clk_i) begin
        //read
        if (reset_i) begin
            ;
        end

        //write
        else if (wr_valid_i) begin
            data_w[wr_addr_i] <= wr_data_i;
        end
    end

endmodule
