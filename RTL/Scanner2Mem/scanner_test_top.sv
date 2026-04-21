// Top-level module for testing scan_controller and scanner_to_mem together
module scanner_test_top (
    input logic clk,
    input logic rst_n,

    // Inputs to scan_controller (driven by testbench)
    input logic frame_start,
    input logic adc_done,
    input logic integration_done,
    input logic [(4*320)-1:0] adc_data,  // 1280 bits
    input logic pixel_ready_from_mem,  // from scanner_to_mem

    // Outputs from scan_controller
    output logic [239:0] row_enable,
    output logic [8:0] bank_sel,  // clog2(320)=9
    output logic [7:0] pixel_row,
    output logic [8:0] pixel_col,  // clog2(320)=9
    output logic integrate,
    output logic adc_start,
    output logic pixel_reset,
    output logic pixel_valid,
    output logic line_done,
    output logic frame_done,
    output logic [(4*320)-1:0] pixel_data,

    // Memory interface (simulated)
    input logic wready_o,  // memory ready
    output logic [15:0] waddr_i,
    output logic [7:0] wdata_i
);

    // Instantiate scan_controller
    scan_controller #(
        .ROWS(240),
        .COLS(320),
        .ADC_BANKS(320),
        .DATA_BITS(4),
        .ADC_TIMEOUT_CYCLES(20)
    ) scan_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .adc_done(adc_done),
        .integration_done(integration_done),
        .adc_data(adc_data),
        .pixel_ready(pixel_ready_from_mem),  // from scanner_to_mem
        .row_enable(row_enable),
        .bank_sel(bank_sel),
        .pixel_row(pixel_row),
        .pixel_col(pixel_col),
        .integrate(integrate),
        .adc_start(adc_start),
        .pixel_reset(pixel_reset),
        .frame_start(frame_start),
        .pixel_valid(pixel_valid),
        .line_done(line_done),
        .frame_done(frame_done),
        .pixel_data(pixel_data)
    );

    // Instantiate scanner_to_mem
    scanner_to_mem #(
        .ROWS(240),
        .COLS(320),
        .DATA_BITS(4)
    ) scan_to_mem (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .pixel_data(pixel_data),
        .pixel_row(pixel_row),
        .pixel_ready(pixel_ready_from_mem),  // to scan_controller
        .waddr_i(waddr_i),
        .wdata_i(wdata_i),
        .wready_o(wready_o)
    );

endmodule