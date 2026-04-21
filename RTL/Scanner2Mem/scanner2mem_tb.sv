`timescale 1ns/1ps

module scanner2mem_tb;

    localparam ROWS               = 4;
    localparam ADC_BANKS          = 4;
    localparam DATA_BITS          = 4;
    localparam RESET_CYCLES       = 3;
    localparam INTEGRATION_CYCLES = 3;
    localparam BYTES_PER_ROW      = ADC_BANKS / 2;  // 2 bytes per row (2 pixels packed per byte)

    logic clk, rst_n;
    logic frame_start, reset_adc, comp_done;
    logic [(DATA_BITS*ADC_BANKS)-1:0] adc_data;

    logic [ROWS-1:0]                  row_enable, row_reset;
    logic                             adc_read_en, adc_start;
    logic [$clog2(ROWS)-1:0]          pixel_row;
    logic                             pixel_valid, row_done, frame_done;
    logic [(DATA_BITS*ADC_BANKS)-1:0] pixel_data;

    logic        wready_o;
    logic [15:0] waddr_i;
    logic [7:0]  wdata_i;

    scanner_test_top #(
        .ROWS              (ROWS),
        .ADC_BANKS         (ADC_BANKS),
        .DATA_BITS         (DATA_BITS),
        .RESET_CYCLES      (RESET_CYCLES),
        .INTEGRATION_CYCLES(INTEGRATION_CYCLES)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_start(frame_start),
        .reset_adc  (reset_adc),
        .comp_done  (comp_done),
        .adc_data   (adc_data),
        .row_enable (row_enable),
        .row_reset  (row_reset),
        .adc_read_en(adc_read_en),
        .adc_start  (adc_start),
        .pixel_row  (pixel_row),
        .pixel_valid(pixel_valid),
        .row_done   (row_done),
        .frame_done (frame_done),
        .pixel_data (pixel_data),
        .wready_o   (wready_o),
        .waddr_i    (waddr_i),
        .wdata_i    (wdata_i)
    );

    // Simple model: record every write scanner_to_mem presents.
    // When scanner_to_mem is in IDLE, waddr/wdata hold stale values from the
    // completed drain (row_q * BPR + 0, byte-0 data) -- safe to overwrite since
    // those same bytes were already written correctly during DRAIN.
    logic [7:0] sim_mem [0:(ROWS*BYTES_PER_ROW)-1];
    always @(posedge clk)
        if (wready_o) sim_mem[waddr_i] <= wdata_i;

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("scanner2mem_tb.vcd");
        $dumpvars(0, scanner2mem_tb);
    end

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge clk);
    endtask

    // Drive one ADC comparison step and wait for it to resolve.
    // last=1: final comparison for this row (reset_adc=1) -> scan_ctrl -> OUTPUT_PIXELS
    // last=0: intermediate comparison                     -> scan_ctrl -> RESET_PIXELS
    task automatic adc_compare_step(input logic last);
        @(posedge adc_read_en);
        wait_cycles(1);
        comp_done = 1;
        reset_adc = last;
        @(posedge clk); #1;
        comp_done = 0;
        reset_adc = 0;
    endtask

    // -------------------------------------------------------
    // Run one full row through: 2 ADC steps then wait for
    // scanner_to_mem to drain and assert pixel_valid low again.
    // -------------------------------------------------------
    task automatic run_row(
        input [(DATA_BITS*ADC_BANKS)-1:0] pdata_mid,
        input [(DATA_BITS*ADC_BANKS)-1:0] pdata_final
    );
        adc_data = pdata_mid;
        adc_compare_step(0);         // intermediate comparison
        adc_data = pdata_final;
        adc_compare_step(1);         // final comparison -- latched as pixel_data
        @(posedge pixel_valid);      // wait for scan_ctrl to present data
        @(negedge pixel_valid);      // wait for scanner_to_mem to finish drain
    endtask

    integer r;
    logic [(DATA_BITS*ADC_BANKS)-1:0] expected [ROWS];

    initial begin
        rst_n       = 0;
        frame_start = 0;
        comp_done   = 0;
        reset_adc   = 0;
        adc_data    = '0;
        wready_o    = 1;

        // ----------------------------------------------------------------
        // TEST 1: outputs clear after reset
        // ----------------------------------------------------------------
        $display("=== TEST 1: reset ===");
        wait_cycles(3);
        rst_n = 1;
        wait_cycles(2);
        assert (pixel_valid == 0) else $error("T1: pixel_valid should be 0");
        assert (frame_done  == 0) else $error("T1: frame_done should be 0");
        assert (adc_read_en == 0) else $error("T1: adc_read_en should be 0");
        assert (row_reset   == '0) else $error("T1: row_reset should be 0");
        $display("  PASS");

        // ----------------------------------------------------------------
        // TEST 2: full frame, memory always ready
        //   Verify sim_mem contains the correct bytes for each row.
        // ----------------------------------------------------------------
        $display("=== TEST 2: full frame, always-ready memory ===");
        for (int i = 0; i < ROWS; i++)
            expected[i] = (i + 1) * {DATA_BITS'(4'hF), {(DATA_BITS*(ADC_BANKS-1)){1'b0}}} | (i+1);
            // Row 0: 0x1..01, Row 1: 0x2..02, etc. -- just need distinct patterns

        // simpler distinct patterns:
        expected[0] = 16'h1234;
        expected[1] = 16'hABCD;
        expected[2] = 16'h5A5A;
        expected[3] = 16'hBEEF;

        frame_start = 1; @(posedge clk); #1; frame_start = 0;

        for (r = 0; r < ROWS; r++) begin
            run_row('0, expected[r]);
            $display("  row %0d done", r);
        end

        @(posedge frame_done);
        wait_cycles(1);

        for (int rr = 0; rr < ROWS; rr++) begin
            for (int b = 0; b < BYTES_PER_ROW; b++) begin
                assert (sim_mem[rr * BYTES_PER_ROW + b] == expected[rr][b*8 +: 8])
                    else $error("T2 FAIL row %0d byte %0d: got 0x%02h expected 0x%02h",
                        rr, b, sim_mem[rr*BYTES_PER_ROW+b], expected[rr][b*8 +: 8]);
            end
        end
        $display("  PASS: sim_mem matches expected pixel data for all rows");

        // ----------------------------------------------------------------
        // TEST 3: memory stall -- wready_o=0 blocks drain, unstall completes
        // ----------------------------------------------------------------
        $display("=== TEST 3: memory stall ===");
        wait_cycles(2);
        wready_o = 0;

        frame_start = 1; @(posedge clk); #1; frame_start = 0;

        // Drive row 0 to OUTPUT_PIXELS
        adc_data = '0;    adc_compare_step(0);
        adc_data = 16'hCAFE; adc_compare_step(1);

        @(posedge pixel_valid);
        wait_cycles(8);  // pixel_valid stays high (stalled)
        assert (pixel_valid == 1) else $error("T3: pixel_valid should stay high during stall");
        $display("  PASS: pixel_valid held high during memory stall");

        // Un-stall: drain should complete and pixel_valid should fall
        wready_o = 1;
        @(negedge pixel_valid);
        // Check the two bytes were written correctly
        assert (sim_mem[0] == 8'hFE) else $error("T3: byte 0 = 0x%02h, expected 0xFE", sim_mem[0]);
        assert (sim_mem[1] == 8'hCA) else $error("T3: byte 1 = 0x%02h, expected 0xCA", sim_mem[1]);
        $display("  PASS: correct bytes written after un-stall");

        wait_cycles(5);
        $display("=== simulation complete ===");
        $finish;
    end

    // Clocked assertions (iverilog-compatible)
    always @(posedge clk) begin
        if (!rst_n) begin
            assert (pixel_valid == 0) else $error("CLKASSERT: pixel_valid during reset");
            assert (adc_read_en == 0) else $error("CLKASSERT: adc_read_en during reset");
            assert (frame_done  == 0) else $error("CLKASSERT: frame_done during reset");
        end
        assert (!(pixel_valid && frame_done))
            else $error("CLKASSERT: pixel_valid and frame_done simultaneously");
        assert ($onehot0(row_reset))
            else $error("CLKASSERT: row_reset not one-hot: %b", row_reset);
        assert ($onehot0(row_enable))
            else $error("CLKASSERT: row_enable not one-hot: %b", row_enable);
    end

    initial begin
        #500000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
