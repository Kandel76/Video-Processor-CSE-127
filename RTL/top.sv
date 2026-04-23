module top #(
    parameter int ROWS               = 240,
    parameter int ADC_BANKS          = 320,
    parameter int DATA_BITS          = 4,
    parameter int RESET_CYCLES       = 20,
    parameter int INTEGRATION_CYCLES = 20,
    parameter int ADC_WAIT_CYCLES    = 1,
    parameter int RAMP_TIME          = 775,
    parameter int PWM_PERIOD         = 15   // full scale for N=4 (duty_cycle 0..15)
)(
    input  logic                           clk,
    input  logic                           rst_n,      // active-low global reset

    // one digital threshold per column (represents analog photodiode voltage)
    input  logic [ADC_BANKS:0]           pixel_in,

    // scanner frame control
    input  logic                           frame_start,
    input  logic                           pixel_ready,

    // pixel output bus (to memory / downstream)
    output logic [$clog2(ROWS)-1:0]        pixel_row,
    output logic                           pixel_valid,
    output logic                           row_done,
    output logic                           frame_done,
    output logic [DATA_BITS*ADC_BANKS-1:0] pixel_data,

    // sensor array row control
    output logic [ROWS-1:0]                row_enable,
    output logic [ROWS-1:0]                row_reset_out
);

    // Reset bridging: scanner/pwm use active-low; ramp_controller active-high
    logic global_reset;
    assign global_reset = ~rst_n;

    // Internal signals

    // ramp_controller <-> pwm
    logic [3:0] duty_cycle;
    logic        pwm_out;
    logic        period_start_out; // available for debug/testbench

    // ramp_controller -> all ADC banks
    logic reset_adc;
    logic valid_voltage;
    logic last_step;

    // scanner -> ramp_controller / ADC banks
    logic adc_start;
    logic adc_read_en;

    // per-bank signals
    logic [ADC_BANKS:0]           cmp_q;
    logic [DATA_BITS*(ADC_BANKS+1)-1:0] adc_data;
    logic [ADC_BANKS:0]           comp_done_per;
    logic [ADC_BANKS:0]           adc_done_per;

    // aggregate comp_done: all banks must finish before ramp steps
    logic comp_done;
    assign comp_done = &comp_done_per[ADC_BANKS:1];

    // PWM  (N=4 matches 4-bit duty_cycle from ramp_controller)
    pwm #(.N(4)) u_pwm (
        .clk             (clk),
        .rst_n           (rst_n),
        .duty_cycle      (duty_cycle),
        .period          (4'(PWM_PERIOD)),
        .pwm_out         (pwm_out),
        .period_start_out(period_start_out)
    );

    // Ramp controller
    ramp_controller #(
        .adc_wait_cycles(ADC_WAIT_CYCLES),
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

    // Scanner
    scanner #(
        .ROWS              (ROWS),
        .ADC_BANKS         (ADC_BANKS),
        .DATA_BITS         (DATA_BITS),
        .RESET_CYCLES      (RESET_CYCLES),
        .INTEGRATION_CYCLES(INTEGRATION_CYCLES)
    ) u_scanner (
        .clk        (clk),
        .rst_n      (rst_n),
        .reset_adc  (reset_adc),
        .last_step  (last_step),
        .row_enable (row_enable),
        .row_reset  (row_reset_out),
        .adc_read_en(adc_read_en),
        .adc_start  (adc_start),
        .comp_done  (comp_done),
        .adc_data   (adc_data),
        .frame_start(frame_start),
        .pixel_ready(pixel_ready),
        .pixel_row  (pixel_row),
        .pixel_valid(pixel_valid),
        .row_done   (row_done),
        .frame_done (frame_done),
        .pixel_data (pixel_data)
    );

    // Per-column: comparator + sar_adc
    genvar i;
    generate
        for (i = 0; i <= ADC_BANKS; i++) begin : g_adc_bank
            comparator u_cmp (
                .clk_i (clk),
                .v_inp (pixel_in[i]),  // per-column pixel threshold
                .v_inm (pwm_out),      // shared ramp from PWM
                .q_o   (cmp_q[i]),
                .q_invo()
            );

            sar_adc u_adc (
                .clk          (clk),
                .cmp_o        (cmp_q[i]),
                .read_en      (adc_read_en),
                .reset_signal (global_reset),
                .adc_reset    (reset_adc),
                .valid_voltage(valid_voltage),
                .adc_o        (adc_data[DATA_BITS*(i+1)-1 : DATA_BITS*i]),
                .adc_done     (adc_done_per[i]),
                .adc_ready    (),
                .comp_done    (comp_done_per[i])
            );
        end
    endgenerate

endmodule
