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
    logic                               adc_start;

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
        .pixel_data   (pixel_data),
        .adc_start     (adc_start)
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
    logic [(DATA_BITS*ADC_BANKS)-1:0] expected_pdata;

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

        assert (pixel_valid == 0) else $error("T1 FAIL: pixel_valid should be 0 after reset");
        assert (frame_done  == 0) else $error("T1 FAIL: frame_done should be 0 after reset");
        assert (adc_read_en == 0) else $error("T1 FAIL: adc_read_en should be 0 after reset");
        assert (row_done    == 0) else $error("T1 FAIL: row_done should be 0 after reset");
        assert (row_reset   == '0) else $error("T1 FAIL: row_reset should be 0 after reset");
        assert (row_enable  == '0) else $error("T1 FAIL: row_enable should be 0 after reset");
        $display("  PASS: all outputs deasserted after reset");

        // ----------------------------------------------------------------
        // TEST 2: idle -- nothing should happen without frame_start
        // ----------------------------------------------------------------
        $display("=== TEST 2: idle, no frame_start ===");
        wait_cycles(5);

        assert (pixel_valid == 0) else $error("T2 FAIL: pixel_valid should stay 0 in idle");
        assert (frame_done  == 0) else $error("T2 FAIL: frame_done should stay 0 in idle");
        assert (adc_read_en == 0) else $error("T2 FAIL: adc_read_en should stay 0 in idle");
        assert (row_done    == 0) else $error("T2 FAIL: row_done should stay 0 in idle");
        $display("  PASS: no outputs asserted during idle");

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
            expected_pdata = {DATA_BITS*ADC_BANKS{1'b0}} | (row * 2 + 1);
            adc_data = expected_pdata;
            adc_compare_step(1);

            // wait for pixel_valid handshake to complete
            @(posedge pixel_valid); #1;

            assert (pixel_row  == row[$clog2(ROWS)-1:0])
                else $error("T3 FAIL row %0d: pixel_row=%0d expected=%0d", row, pixel_row, row);
            assert (pixel_data == expected_pdata)
                else $error("T3 FAIL row %0d: pixel_data=0x%0h expected=0x%0h", row, pixel_data, expected_pdata);
            $display("  PASS row %0d: pixel_row=%0d pixel_data=0x%0h", row, pixel_row, pixel_data);

            wait_cycles(1);
        end

        // wait for frame_done
        @(posedge frame_done);
        $display("=== frame_done received ===");
        wait_cycles(1);

        // FSM returns to IDLE after frame_done -- all drive signals should clear
        assert (pixel_valid == 0) else $error("T3 FAIL: pixel_valid should be 0 after frame_done");
        assert (adc_read_en == 0) else $error("T3 FAIL: adc_read_en should be 0 after frame_done");
        assert (row_reset   == '0) else $error("T3 FAIL: row_reset should be 0 after frame_done");
        assert (row_enable  == '0) else $error("T3 FAIL: row_enable should be 0 after frame_done");
        $display("  PASS: outputs clear after frame_done");
        wait_cycles(2);

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
        expected_pdata = 16'h1234;
        adc_data = expected_pdata;
        adc_compare_step(1);
        @(posedge pixel_valid); #1;

        assert (pixel_row  == 0)
            else $error("T4 FAIL: pixel_row should be 0 for first row of second frame, got %0d", pixel_row);
        assert (pixel_data == expected_pdata)
            else $error("T4 FAIL: pixel_data=0x%0h expected=0x%0h", pixel_data, expected_pdata);
        $display("  PASS: second frame row 0 pixel_row=%0d pixel_data=0x%0h", pixel_row, pixel_data);

        wait_cycles(5);

        $display("=== simulation complete ===");
        $finish;
    end

    // -------------------------------------------------------
    // Clocked assertions (checked every posedge — iverilog compatible)
    // -------------------------------------------------------
    always @(posedge clk) begin
        // no outputs driven while in reset
        if (!rst_n) begin
            assert (pixel_valid == 0) else $error("CLKASSERT FAIL: pixel_valid asserted during reset");
            assert (adc_read_en == 0) else $error("CLKASSERT FAIL: adc_read_en asserted during reset");
            assert (frame_done  == 0) else $error("CLKASSERT FAIL: frame_done asserted during reset");
        end

        // pixel_valid and frame_done must not be high in the same cycle
        assert (!(pixel_valid && frame_done))
            else $error("CLKASSERT FAIL: pixel_valid and frame_done asserted simultaneously");

        // only one row may be reset or enabled at a time
        assert ($onehot0(row_reset))
            else $error("CLKASSERT FAIL: row_reset is not one-hot, value=%0b", row_reset);
        assert ($onehot0(row_enable))
            else $error("CLKASSERT FAIL: row_enable is not one-hot, value=%0b", row_enable);

        // ADC must not be read while pixels are being reset
        if (|row_reset)
            assert (adc_read_en == 0)
                else $error("CLKASSERT FAIL: adc_read_en high while row_reset is active");
    end

    // timeout watchdog
    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
