// Top-level wrapper combining scan_controller and scanner_to_mem for testbench use.
module scanner_test_top #(
    parameter int ROWS               = 240,
    parameter int ADC_BANKS          = 320,
    parameter int DATA_BITS          = 4,
    parameter int RESET_CYCLES       = 10,
    parameter int INTEGRATION_CYCLES = 10
)(
    input  logic clk,
    input  logic rst_n,

    // Inputs to scan_controller
    input  logic                             frame_start,
    input  logic                             reset_adc,
    input  logic                             comp_done,
    input  logic [(DATA_BITS*ADC_BANKS)-1:0] adc_data,

    // Outputs from scan_controller (observable by testbench)
    output logic [ROWS-1:0]                  row_enable,
    output logic [ROWS-1:0]                  row_reset,
    output logic                             adc_read_en,
    output logic                             adc_start,
    output logic [$clog2(ROWS)-1:0]          pixel_row,
    output logic                             pixel_valid,
    output logic                             row_done,
    output logic                             frame_done,
    output logic [(DATA_BITS*ADC_BANKS)-1:0] pixel_data,

    // Memory interface
    input  logic                             wready_o,
    output logic [15:0]                      waddr_i,
    output logic [7:0]                       wdata_i
);

    logic pixel_ready_int;

    scan_controller #(
        .ROWS              (ROWS),
        .ADC_BANKS         (ADC_BANKS),
        .DATA_BITS         (DATA_BITS),
        .RESET_CYCLES      (RESET_CYCLES),
        .INTEGRATION_CYCLES(INTEGRATION_CYCLES)
    ) scan_ctrl (
        .clk         (clk),
        .rst_n       (rst_n),
        .reset_adc   (reset_adc),
        .comp_done   (comp_done),
        .adc_data    (adc_data),
        .frame_start (frame_start),
        .pixel_ready (pixel_ready_int),
        .row_enable  (row_enable),
        .row_reset   (row_reset),
        .adc_read_en (adc_read_en),
        .adc_start   (adc_start),
        .pixel_row   (pixel_row),
        .pixel_valid (pixel_valid),
        .row_done    (row_done),
        .frame_done  (frame_done),
        .pixel_data  (pixel_data)
    );

    scanner_to_mem #(
        .ROWS     (ROWS),
        .COLS     (ADC_BANKS),
        .DATA_BITS(DATA_BITS)
    ) scan_to_mem (
        .clk         (clk),
        .rst_n       (rst_n),
        .pixel_valid (pixel_valid),
        .pixel_data  (pixel_data),
        .pixel_row   (pixel_row),
        .pixel_ready (pixel_ready_int),
        .waddr_i     (waddr_i),
        .wdata_i     (wdata_i),
        .wready_o    (wready_o)
    );

endmodule
