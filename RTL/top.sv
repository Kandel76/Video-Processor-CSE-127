
module top #(
    parameter int ROWS               = 240,
    parameter int COLS               = 320,
    parameter int DATA_BITS          = 4,
    parameter int RESET_CYCLES       = 2, //keep these low for faster sim
    parameter int INTEGRATION_CYCLES = 2,
    parameter int RAMP_TIME          = 4
)(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              frame_start,

    // Comparator results driven by cocotb (one bit per column + dark ref)
    input  logic [COLS:0]                     cmp_q,

    output logic [3:0]                        duty_cycle,   //this would be the digital "reference voltage" in this simulation
    output logic                              adc_read_en,  //only for status, not needed for functionality

    // Memory write port
    output logic [15:0]                       waddr_o,
    output logic [7:0]                        wdata_o,
    input  logic                              wready_i,

    // Status outputs
    output logic [$clog2(ROWS)-1:0]           current_row,
    output logic                              row_data_valid,
    output logic                              row_done,
    output logic                              frame_done
);

    localparam ADC_DATA_W  = DATA_BITS * (COLS + 1);
    localparam PIXEL_BUS_W = DATA_BITS * COLS;

    logic global_reset;
    assign global_reset = ~rst_n;

    logic                   reset_adc, valid_voltage, last_step;
    logic                   adc_start;
    logic                   comp_done;

    logic [ADC_DATA_W-1:0]  adc_data;
    logic [COLS:0]          comp_done_per, adc_done_per;

    logic [ROWS-1:0]        row_enable, row_reset_scan;
    logic [PIXEL_BUS_W-1:0] row_data;
    logic                   row_data_ready;

    assign comp_done = &comp_done_per[COLS:1];

    ramp_controller #(
        .ramp_time      (RAMP_TIME)
    ) u_ramp (
        .clk          (clk),
        .global_reset (global_reset),
        .comp_done    (comp_done),
        .adc_start    (adc_start),
        .duty_cycle   (duty_cycle),
        .reset_adc    (reset_adc),
        .valid_voltage(valid_voltage),
        .last_step    (last_step)
    );

    scanner #(
        .ROWS              (ROWS),
        .ADC_BANKS         (COLS),
        .DATA_BITS         (DATA_BITS),
        .RESET_CYCLES      (RESET_CYCLES),
        .INTEGRATION_CYCLES(INTEGRATION_CYCLES)
    ) u_scanner (
        .clk           (clk),
        .rst_n         (rst_n),
        .ramp_done     (reset_adc),
        .last_step     (last_step),
        .row_enable    (row_enable),
        .row_reset     (row_reset_scan),
        .adc_read_en   (adc_read_en),
        .adc_start     (adc_start),
        .comp_done     (comp_done),
        .adc_data      (adc_data),
        .frame_start   (frame_start),
        .row_data_ready(row_data_ready),
        .current_row   (current_row),
        .row_data_valid(row_data_valid),
        .row_done      (row_done),
        .frame_done    (frame_done),
        .row_data      (row_data)
    );

    scanner_to_mem #(
        .ROWS     (ROWS),
        .COLS     (COLS),
        .DATA_BITS(DATA_BITS)
    ) u_s2m (
        .clk           (clk),
        .rst_n         (rst_n),
        .row_data_valid(row_data_valid),
        .row_data      (row_data),
        .current_row   (current_row),
        .row_data_ready(row_data_ready),
        .waddr_i       (waddr_o),
        .wdata_i       (wdata_o),
        .wready_o      (wready_i)
    );

    genvar gi;
    generate
        for (gi = 0; gi <= COLS; gi++) begin : g_col
            sar_adc #() u_adc (
                .clk          (clk),
                .cmp_o        (cmp_q[gi]),
                .read_en      (adc_read_en),
                .reset_signal (global_reset),
                .adc_reset    (reset_adc),
                .valid_voltage(valid_voltage),
                .adc_o        (adc_data[DATA_BITS*(gi+1)-1 : DATA_BITS*gi]),
                .adc_done     (adc_done_per[gi]),
                .adc_ready    (),
                .comp_done    (comp_done_per[gi])
            );
        end
    endgenerate

endmodule
