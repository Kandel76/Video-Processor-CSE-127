//scanner module
// 320 column parallel ADC's reading at the same time
//using One Ramp style ADC, each row being read at the same time
//diodes are reset and re-integrated after each comparison
//controls the reset and integration of diode
//controls when adc starts
//controls the output of pixel data and valid signal for memory mapping
//controls the iteration of all rows, columns are parallel so no need to iterate through


module scan_controller #(
    parameter int ROWS = 240,
    parameter int ADC_BANKS = 320,
    parameter int DATA_BITS = 4,
    parameter int RESET_CYCLES = 10, //number of cycles to hold reset signal for pixels
    parameter int INTEGRATION_CYCLES = 10 //number of cycles to hold integrate signal for pixels
)(

    input logic clk,
    input logic rst_n,   //ACTIVE LOW

    //from the ramp controller
    input logic reset_adc, //signals when to go to next row since all comparion are done

    //To the photodiodes -- this module handles reset and integration after each row and each operation of comparators
    //integrating means row_enable is high for N cycles
    output logic [ROWS-1:0]                   row_enable,    //should this be one hot for row_en?
    output logic [ROWS-1:0]                   row_reset,     //start the reset of the pixels, should be held for N cycles for the reset time -- One hot

    //To the ADC
    output logic                              adc_read_en, //starts the adc to enable reading
    output logic                              adc_start,   //triggers ADC conversion start

    //From the ADC Module
    input logic comp_done,
    input logic [(DATA_BITS*ADC_BANKS)-1:0] adc_data,  //data from the ADC

    //For memory mapping and control
    input  logic                              frame_start, //FOR ANOTHER MODULE to start a new frame (later used to frame rate control)
    input  logic                              pixel_ready, //downstream handshake: consumer is ready to accept pixel data
    output logic [$clog2(ROWS)-1:0]           pixel_row, //current row being output -- used for mapping to pixel array
    output logic                              pixel_valid,  //used later for mapping
    output logic                              row_done, //signal end of a row
    output logic                              frame_done,  //signals when the entire fram is complete
    output logic [(DATA_BITS*ADC_BANKS)-1:0]  pixel_data
);


    // State encoding
    typedef enum logic [2:0] {
        IDLE, //default state, waiting for frame_start signal
        RESET_PIXELS, //should be reset after each comparison and new row
        INTEGRATE,  //should be done as same time as reset, but can be extended for longer integration times
        WAIT_CONVERT,
        OUTPUT_PIXELS,
        NEXT_ROW,
        FRAME_DONE
    } state_t;

    //state_d - next state
    //state_q - current state
    state_t state_d, state_q;

    //counters
    logic [$clog2(ROWS)-1:0]       row_cnt_d, row_cnt_q;   //row counter
    logic [$clog2(INTEGRATION_CYCLES > RESET_CYCLES ? INTEGRATION_CYCLES : RESET_CYCLES)-1:0] phase_cnt_d, phase_cnt_q; //shared timer for RESET and INTEGRATE phases, choosees width on which is larger
    logic [DATA_BITS*ADC_BANKS-1:0] pixel_data_d, pixel_data_q; //register to hold pixel data from ADC
    logic pixel_valid_d, pixel_valid_q; //register to hold pixel valid signal

// driving d_ff
always_ff @(posedge clk) begin
    if (!rst_n) begin
        state_q       <= IDLE;
        row_cnt_q     <= 0;
        phase_cnt_q   <= 0;
        pixel_data_q  <= 0;
        pixel_valid_q <= 0;
    end else begin
        state_q       <= state_d;
        row_cnt_q     <= row_cnt_d;
        phase_cnt_q   <= phase_cnt_d;
        pixel_data_q  <= pixel_data_d;
        pixel_valid_q <= pixel_valid_d;
    end
end

//comb logic
    always_comb begin
        // Default state changes
        state_d      = state_q;
        row_cnt_d    = row_cnt_q;
        phase_cnt_d  = phase_cnt_q;
        pixel_data_d = pixel_data_q;
        
        
        // Default outputs
        frame_done    = 0;
        pixel_row     = row_cnt_q;
        row_done      = 0;
        pixel_valid_d = pixel_valid_q;
        row_reset     = 0;
        row_enable    = 0;
        adc_read_en   = 0;
        adc_start     = 0;
        case (state_q)
            IDLE: begin
                //wait for a flag to start the next frame
                if (frame_start) begin
                    state_d     = RESET_PIXELS;
                    row_cnt_d   = 0;
                    phase_cnt_d = 0;
                    pixel_data_d = 0;
                end

            end

            RESET_PIXELS: begin
                row_reset[row_cnt_q] = 1;
                phase_cnt_d = phase_cnt_q + 1;
                if (phase_cnt_q >= RESET_CYCLES - 1) begin
                    phase_cnt_d = 0;
                    state_d = INTEGRATE;
                end
            end

            INTEGRATE: begin
                row_enable[row_cnt_q] = 1;
                phase_cnt_d = phase_cnt_q + 1;
                if (phase_cnt_q >= INTEGRATION_CYCLES - 1) begin
                    phase_cnt_d = 0;
                    state_d = WAIT_CONVERT;
                end
            end


            WAIT_CONVERT: begin
                row_enable[row_cnt_q] = 1; //keep row enabled
                adc_start = 1; //start the adc conversion
                adc_read_en = 1; //enable the adc so it starts reading

                if (comp_done && reset_adc) begin //check if all comparisons done for this row
                    pixel_data_d = adc_data;
                    state_d = OUTPUT_PIXELS;
                end else if (comp_done) begin //comparison done, step to next reference voltage
                    state_d = RESET_PIXELS;
                end
            end

            OUTPUT_PIXELS: begin
                pixel_valid_d = 1;

                //this is for the other modules taking in pixel data
                if (pixel_ready) begin
                    pixel_valid_d = 0;
                    state_d = NEXT_ROW; //next state
                end
            end


            NEXT_ROW: begin
                if (row_cnt_q == ROWS-1) begin
                    row_done = 1;
                    state_d = FRAME_DONE;
                end else begin
                    row_cnt_d = row_cnt_q + 1;
                    phase_cnt_d = 0;
                    row_done = 1;
                    state_d = RESET_PIXELS;
                end
            end

            FRAME_DONE: begin
                frame_done = 1;
                state_d = IDLE;
            end

            default: begin
                state_d = IDLE;
            end

        endcase

    end


assign pixel_data = pixel_data_q;
assign pixel_valid = pixel_valid_q;


endmodule
