`timescale 1ns/1ps

module top #(
    parameter int ROWS               = 240,
    parameter int COLS               = 320,  //dimensions of diode array (321, including dark reference column (includeing zero))
    parameter int DATA_BITS          = 4,
    parameter int RESET_CYCLES       = 10,  //CHANGE THIS
    parameter int INTEGRATION_CYCLES = 10,  //CHANGE THIS
    parameter int RAMP_TIME          = 213 //should be atleast 213
)(
    input  logic                              clk,       //25MHz main clock
    input  logic                              pwm_clk,   //100MHz clk for PWM generator)

    input  logic                              rst_n, //active low

    // Comparator results  --- is this needed?? maybe use verilog model comparator
    input  logic [COLS:0]                     cmp_o,

    // VGA outputs
    output logic                              hsync_o,
    output logic                              vsync_o,
    output logic [11:0]                       pixel_o,

    // Off-chip SRAM interface (Hitachi memory)
    output logic [14:0]                       mem_addr_o,
    output logic                              mem_nCS1_o,
    output logic                              mem_nCS2_o,
    output logic                              mem_nOE_o,
    output logic                              mem_nWE_o,
    output logic [7:0]                        mem_data_o,
    input  logic [7:0]                        mem_data_i,

    //RC FILTER OUTPUT
    output logic                              pwm_out

);

    localparam ADC_DATA_W    = DATA_BITS * (COLS + 1); //+1 for dark reference column
    localparam ROW_DATA_BUS_W = DATA_BITS * COLS; //not including dark col

    //reset bridge
    logic global_reset;
    assign global_reset = ~rst_n;

    //internal signals
    logic                   reset_adc, valid_voltage, last_step;
    logic                   ramp_start;
    logic                   comp_done;

    logic [ADC_DATA_W-1:0]  adc_data;
    logic [COLS:0]          comp_done_per, adc_done_per;

    logic [ROWS-1:0]        row_enable, row_reset_scan;
    logic [ROW_DATA_BUS_W-1:0] row_data;
    logic                   row_data_ready;

    // Internal write bus connecting scanner_to_mem -> mem2vga
    logic [15:0]            waddr_w;
    logic [7:0]             wdata_w;
    logic                   wready_w;
    logic                   wvalid_w;

    assign comp_done = &comp_done_per[COLS:1];  // comp done when all columns (except dark ref) are done


    ramp_controller #(
        .ramp_time      (RAMP_TIME)
    ) u_ramp (
        .clk          (clk),
        .global_reset (global_reset),
        .comp_done    (comp_done),
        .adc_start    (ramp_start),
        .duty_cycle   (duty_cycle),
        .reset_adc    (reset_adc),
        .valid_voltage(valid_voltage),
        .last_step    (last_step)
    );

    pwm #(
        .N(4)
    ) u_pwm (
        .clk             (clk),
        .rst_n           (rst_n),
        .duty_cycle      (duty_cycle),
        .period          (4'd15),
        .pwm_out         (pwm_out),
        .period_start_out()         //not used
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
        .adc_start     (ramp_start),
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
        .waddr_i       (waddr_w),
        .wdata_i       (wdata_w),
        .wready_o      (wready_w),
        .wvalid_o      (wvalid_w) //to mem2vga stating that data is valid
    );

    mem2vga u_m2v (
        .clk      (clk),
        .reset    (global_reset),
        .active_o (active_o),
        .hsync_o  (hsync_o),
        .vsync_o  (vsync_o),
        .pixel_o  (pixel_o),
        .waddr_i  (waddr_w),
        .wdata_i  (wdata_w),
        .wvalid_i (wvalid_w),
        .wready_o (wready_w),
        .addr_o   (mem_addr_o),
        .nCS1_o   (mem_nCS1_o),
        .nCS2_o   (mem_nCS2_o),
        .nOE_o    (mem_nOE_o),
        .nWE_o    (mem_nWE_o),
        .data_o   (mem_data_o),
        .data_i   (mem_data_i)
    );

    //get parallel adcs for each column
    genvar gi;
    generate
        for (gi = 0; gi <= COLS; gi++) begin : g_col
            sar_adc #() u_adc (
                .clk          (clk),
                .cmp_o        (cmp_o[gi]),
                .read_en      (adc_read_en),
                .reset_signal (global_reset),
                .adc_reset    (reset_adc),
                .valid_voltage(valid_voltage),
                .adc_o        (adc_data[DATA_BITS*(gi+1)-1 : DATA_BITS*gi]),
                .adc_done     (adc_done_per[gi]),
                .adc_ready    (), //not used since we control the timing with adc_read_en
                .comp_done    (comp_done_per[gi])
            );
        end
    endgenerate

endmodule
