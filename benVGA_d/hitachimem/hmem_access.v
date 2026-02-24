module hmem_access (
    input [0:0] clk,
    input [0:0] reset,

    //interface side
    input [0:0] ready_i,
    output logic [0:0] valid_o,
    output logic [7:0] data_o,

    //memory side
    output logic [0:0] ready_o,
    input [0:0] valid_i,
    input [7:0] data_i
);

    always @(posedge clk) begin
        if (reset) begin
            ready_o <= 1'b0;
            valid_o <= 1'b0;
            data_o <= 1'b0;
        end else begin
            ready_o <= ready_i;
            valid_o <= valid_i;
            if (valid_i) begin
                data_o <= data_i;
            end
        end
    end

endmodule
