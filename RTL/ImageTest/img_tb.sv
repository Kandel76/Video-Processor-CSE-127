`timescale 1ns/1ps

// Image round-trip testbench.
// Feeds pixel data row-by-row into the scanner FSM and scanner_to_mem,
// then saves what came out to a file for Python to check.
// The ADC, comparator, and ramp are not included — pixel values are injected directly.

module img_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam ROWS               = 240;
    localparam COLS               = 320;
    localparam DATA_BITS          = 4;
    localparam RESET_CYCLES       = 2;
    localparam INTEGRATION_CYCLES = 2;

    // Widths derived from the above
    localparam ADC_DATA_W    = DATA_BITS * (COLS + 1); // 1284 bits: dark ref + 320 pixels
    localparam PIXEL_BUS_W   = DATA_BITS * COLS;       // 1280 bits: 320 pixels × 4 bits
    localparam BYTES_PER_ROW = COLS / 2;               // 160 bytes: two 4-bit pixels per byte
    localparam TOTAL_BYTES   = ROWS * BYTES_PER_ROW;   // 38400 bytes total

    // Signals
    logic clk, rst_n;
    logic frame_start;
    logic reset_adc, comp_done, last_step;
    logic [ADC_DATA_W-1:0]   adc_data;    // pixel values we inject into the scanner

    logic [ROWS-1:0]          row_enable, row_reset;
    logic                     adc_read_en, adc_start;
    logic [$clog2(ROWS)-1:0]  pixel_row;
    logic                     pixel_valid, row_done, frame_done;
    logic [PIXEL_BUS_W-1:0]   pixel_data;

    logic                     pixel_ready;
    logic [15:0]              waddr_i;   // address scanner_to_mem writes to
    logic [7:0]               wdata_i;   // byte scanner_to_mem writes
    logic                     wready_o;  // memory ready signal (always 1 here)

    // Storage arrays

    // One entry per row — loaded from input_pixels.hex at the start
    logic [ADC_DATA_W-1:0] input_mem [0:ROWS-1];

    // Flat byte array — filled by capturing what scanner_to_mem writes
    logic [7:0] output_mem [0:TOTAL_BYTES-1];

    // -------------------------------------------------------------------------
    // DUT instantiations
    // -------------------------------------------------------------------------

    scanner #(
        .ROWS              (ROWS),
        .ADC_BANKS         (COLS),
        .DATA_BITS         (DATA_BITS),
        .RESET_CYCLES      (RESET_CYCLES),
        .INTEGRATION_CYCLES(INTEGRATION_CYCLES)
    ) u_scanner (
        .clk        (clk),
        .rst_n      (rst_n),
        .reset_adc  (reset_adc),
        .last_step  (last_step),
        .row_enable (row_enable),
        .row_reset  (row_reset),
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

    // Memory is always ready to accept data in this testbench
    assign wready_o = 1'b1;

    scanner_to_mem #(
        .ROWS     (ROWS),
        .COLS     (COLS),
        .DATA_BITS(DATA_BITS)
    ) u_s2m (
        .clk        (clk),
        .rst_n      (rst_n),
        .pixel_valid(pixel_valid),
        .pixel_data (pixel_data),
        .pixel_row  (pixel_row),
        .pixel_ready(pixel_ready),
        .waddr_i    (waddr_i),
        .wdata_i    (wdata_i),
        .wready_o   (wready_o)
    );

    // Record every byte scanner_to_mem puts on the bus
    always @(posedge clk)
        output_mem[waddr_i] <= wdata_i;

    initial clk = 0;
    always #5 clk = ~clk;

    integer fd, row;

    initial begin

        $readmemh("input_pixels.hex", input_mem); //load image

        rst_n       = 0; //load all default values and reset
        frame_start = 0;
        reset_adc   = 0;
        comp_done   = 0;
        last_step   = 0;
        adc_data    = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        frame_start = 1; //start a new frame
        @(posedge clk); #1;
        frame_start = 0; //the state machine shoud NOT be in IDLE after this

        // --- Step 4: Feed pixel data row by row ---
        for (row = 0; row < ROWS; row++) begin

            // Put this row's pixel values on the adc_data bus
            adc_data = input_mem[row];

            // Wait until the scanner is ready to receive ADC results
            // (it raises adc_read_en when it enters the WAIT_CONVERT state)
            @(posedge adc_read_en);
            @(posedge clk);

            // Tell the scanner the ADC is done — it will latch adc_data
            // and move straight to outputting the pixel data
            reset_adc = 1;
            @(posedge clk); #1;
            reset_adc = 0;

            // Wait for scanner_to_mem to finish writing this row's bytes
            @(negedge pixel_valid);

        end

        //  Wait for the scanner to signal the full frame is done 
        @(posedge frame_done);
        repeat(2) @(posedge clk);

        // Save output bytes to file for check_output.py
        fd = $fopen("output_pixels.hex", "w");
        for (int i = 0; i < TOTAL_BYTES; i++)
            $fdisplay(fd, "%02h", output_mem[i]);
        $fclose(fd);

        $display("Done — output saved to output_pixels.hex");
        $finish;
    end

    // Timeout 
    initial begin
        #5_000_000;
        $display("TIMEOUT — simulation took too long");
        $finish;
    end

endmodule
