`timescale 1ns/1ps

module scanner_tb;

    // small parameters so simulation is fast and waveforms are readable
    localparam ROWS             = 4;
    localparam ADC_BANKS        = 4;
    localparam DATA_BITS        = 4;
    localparam RESET_CYCLES     = 3;
    localparam INTEGRATION_CYCLES = 3;

    logic clk;
    logic rst_n;
    logic reset_adc;
    logic [ROWS-1:0]                    row_enable;
    logic [ROWS-1:0]                    row_reset;
    logic                               adc_read_en;
    logic                               comp_done;
    logic [(DATA_BITS*ADC_BANKS)-1:0]   adc_data;
    logic                               frame_start;
    logic                               pixel_ready;
    logic [$clog2(ROWS)-1:0]            pixel_row;
    logic                               pixel_valid;
    logic                               row_done;
    logic                               frame_done;
    logic [(DATA_BITS*ADC_BANKS)-1:0]   pixel_data;

    scan_controller #(
        .ROWS              (ROWS),
        .ADC_BANKS         (ADC_BANKS),
        .DATA_BITS         (DATA_BITS),
        .RESET_CYCLES      (RESET_CYCLES),
        .INTEGRATION_CYCLES(INTEGRATION_CYCLES)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .reset_adc    (reset_adc),
        .row_enable   (row_enable),
        .row_reset    (row_reset),
        .adc_read_en  (adc_read_en),
        .comp_done    (comp_done),
        .adc_data     (adc_data),
        .frame_start  (frame_start),
        .pixel_ready  (pixel_ready),
        .pixel_row    (pixel_row),
        .pixel_valid  (pixel_valid),
        .row_done     (row_done),
        .frame_done   (frame_done),
        .pixel_data   (pixel_data)
    );

    // 10ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // waveform dump
    initial begin
        $dumpfile("scanner_tb.vcd");
        $dumpvars(0, scanner_tb);
    end

    // helper task: wait N clock cycles
    task wait_cycles(input int n);
        repeat(n) @(posedge clk);
    endtask

    // helper task: fire a single ADC comparison (not the last one for this row)
    task adc_compare_step(input logic last);
        // wait for adc_read_en to go high, then fire comp_done
        @(posedge adc_read_en);
        wait_cycles(1);
        comp_done  = 1;
        reset_adc  = last;
        @(posedge clk); #1;
        comp_done  = 0;
        reset_adc  = 0;
    endtask

    integer row, step;

    initial begin
        // initialise inputs
        rst_n       = 0;
        frame_start = 0;
        comp_done   = 0;
        reset_adc   = 0;
        pixel_ready = 1;          // always ready to accept pixel data
        adc_data    = '0;

        // ----------------------------------------------------------------
        // TEST 1: reset behaviour
        // ----------------------------------------------------------------
        $display("=== TEST 1: reset ===");
        wait_cycles(3);
        rst_n = 1;
        wait_cycles(2);

        // ----------------------------------------------------------------
        // TEST 2: idle -- nothing should happen without frame_start
        // ----------------------------------------------------------------
        $display("=== TEST 2: idle, no frame_start ===");
        wait_cycles(5);

        // ----------------------------------------------------------------
        // TEST 3: full frame -- 4 rows, 2 comparison steps per row
        //   step 0: comp_done=1, reset_adc=0  -> loops back to RESET_PIXELS
        //   step 1: comp_done=1, reset_adc=1  -> goes to OUTPUT_PIXELS
        // ----------------------------------------------------------------
        $display("=== TEST 3: full frame ===");
        frame_start = 1;
        @(posedge clk); #1;
        frame_start = 0;

        for (row = 0; row < ROWS; row++) begin
            $display("-- row %0d --", row);

            // step 0: mid-ramp comparison, loop back
            adc_data = {DATA_BITS*ADC_BANKS{1'b0}} | (row * 2);  // dummy data
            adc_compare_step(0);

            // step 1: final comparison, capture and output
            adc_data = {DATA_BITS*ADC_BANKS{1'b0}} | (row * 2 + 1);
            adc_compare_step(1);

            // wait for pixel_valid handshake to complete
            @(posedge pixel_valid);
            wait_cycles(1);
        end

        // wait for frame_done
        @(posedge frame_done);
        $display("=== frame_done received ===");
        wait_cycles(3);

        // ----------------------------------------------------------------
        // TEST 4: second frame starts cleanly
        // ----------------------------------------------------------------
        $display("=== TEST 4: second frame ===");
        frame_start = 1;
        @(posedge clk); #1;
        frame_start = 0;

        // just do one row to confirm the FSM restarted
        adc_data = 16'hABCD;
        adc_compare_step(0);
        adc_data = 16'h1234;
        adc_compare_step(1);
        @(posedge pixel_valid);
        wait_cycles(5);

        $display("=== simulation complete ===");
        $finish;
    end

    // timeout watchdog
    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
