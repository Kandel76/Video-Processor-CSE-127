module scan_controller #(
    parameter int ROWS = 240,
    parameter int COLS = 320,
    parameter int ADC_BANKS = 320,
    parameter int DATA_BITS = 4, 
    parameter int PIXEL_BUS_WIDTH = DATA_BITS * (COLS / ADC_BANKS), //total bits read from ADC each step
    parameter int ADC_TIMEOUT_CYCLES = 20
)(
    //inputs
    input logic clk,
    input logic rst_n,   //ACTIVE LOW
    input logic adc_done,   //signals when all ADC conversions for the current step are done
    input logic integration_done, //signals when pixel integration time is complete
    input logic [(DATA_BITS*ADC_BANKS)-1:0] adc_data,  //data from the ADC 
    input logic pixel_ready,  //ready signal from array, pixel data can be used
    input logic frame_start, //FOR ANOTHER MODULE to start a new frame (later used to frame rate control)
    
    //outputs
    output logic                              frame_done,  //signals when the entire fram is complete
    output logic                              line_done, //signal end of a row
    output logic [ROWS-1:0]                   row_enable,    //should this be one hot or indexed for row_en?
    output logic [$clog2(ADC_BANKS)-1:0]      bank_sel, //which bank to start conversion on
    output logic                              adc_start, //start conversion for the specifc adc
    output logic [(DATA_BITS*ADC_BANKS)-1:0]    pixel_data, 
    output logic [$clog2(ROWS)-1:0]           pixel_row, //current row being output -- used for mapping to pixel array
    output logic [$clog2(COLS)-1:0]           pixel_col, //current col being output -- used for mapping to pixel array
    output logic                              pixel_valid,  //used later for mapping
    output logic                              pixel_reset, //global reset for pixels at the start of each frame
    output logic                              integrate //signal to start integration time for pixels
);
    
    localparam int STEPS_PER_ROW = COLS / (ADC_BANKS);  //strides
    logic timeout; //for when the ADC takes too long


    // State encoding
    typedef enum logic [3:0] {
        IDLE,
        RESET_PIXELS,
        INTEGRATE,
        SELECT_ROW,
        START_CONVERT,
        WAIT_CONVERT,
        OUTPUT_PIXELS,
        NEXT_ROW,
        FRAME_DONE
    } state_t;
    
    //state_d - next state
    //state_q - current state
    state_t state_d, state_q; 
    
    //counters
    logic [$clog2(ROWS)-1:0]     row_cnt_d, row_cnt_q;   //row counter
    logic [$clog2(STEPS_PER_ROW)-1:0] step_cnt_d, step_cnt_q;  //step counter for columns
    logic [$clog2(ADC_TIMEOUT_CYCLES)-1:0] timeout_cnt_d, timeout_cnt_q; //timeout counter for ADC
    logic [DATA_BITS*ADC_BANKS-1:0] pixel_data_d, pixel_data_q; //register to hold pixel data from ADC
    logic pixel_valid_d, pixel_valid_q; //register to hold pixel valid signal

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state1_q       <= IDLE;
        row_cnt_q     <= 0;
        step_cnt_q    <= 0;
        timeout_cnt_q <= 0;
        pixel_data_q  <= 0;
        pixel_valid_q <= 0;
    end else begin
        state_q       <= state_d;
        row_cnt_q     <= row_cnt_d;
        step_cnt_q    <= step_cnt_d;
        timeout_cnt_q <= timeout_cnt_d;
        pixel_data_q  <= pixel_data_d;
        pixel_valid_q <= pixel_valid_d;
    end
end

// driving d_ff
    always_comb begin
        // Default next values
        state_d       = state_q;
        row_cnt_d     = row_cnt_q;
        step_cnt_d    = step_cnt_q;
        timeout_cnt_d = timeout_cnt_q;
        pixel_data_d  = pixel_data_q;
        // Default outputs
        integrate = 0;
        frame_done  = 0;
        row_enable  = '0;
        adc_start   = 0;
        pixel_valid = 0;
        pixel_reset = 0;
        pixel_row   = row_cnt_q;
        pixel_col   = step_cnt_q * ADC_BANKS;
        line_done    = 0;
        pixel_valid_d = pixel_valid_q
        case (state_q)
            IDLE: begin
                //wait for a flag to start the next frame
                if (frame_start) begin
                    state_d = RESET_PIXELS; 
                    row_cnt_d = 0;
                    step_cnt_d = 0;
                    timeout_cnt_d = 0;
                end

            end
            
            RESET_PIXELS: begin
                // global reset of pixels, thats it
                pixel_reset = 1;
                state_d = INTEGRATE;
            end
            
            INTEGRATE: begin
                //this activats integrate signal and waits for the integration done signal to proceed
                integrate = 1; //start integration time for pixels
                timeout_cnt_d = timeout_cnt_q + 1; //increment timeout counter for integration time

                if(integration_done || timeout) begin
                    state_d = SELECT_ROW;
                    timeout_cnt_d = 0; //reset timeout counter for ADC conversion
                end
            end
            
            SELECT_ROW: begin

                row_enable[row_cnt_q] = 1; //enable current row
                state_d = START_CONVERT;

            end
            
            START_CONVERT: begin

                row_enable[row_cnt_q] = 1; //keep row enabled
                pixel_col = step_cnt_q * ADC_BANKS; //select starting column for this step
                adc_start = 1;  // pulse to signal ADC to start conversion
                state_d = WAIT_CONVERT;

            end
            
            WAIT_CONVERT: begin
                row_enable[row_cnt_q] = 1; //keep row enabled
                pixel_col = step_cnt_q * ADC_BANKS; //keep column selected
                timeout_cnt_d = timeout_cnt_q + 1; //increment timeout counter while waiting for ADC
                
                if (adc_done || timeout) begin
                    state_d = OUTPUT_PIXELS;
                    timeout_cnt_d = 0; //reset timeout counter for next step
                    //if adc is high, capture data, if timeout, pixel data will be 0
                    if (adc_done) begin
                        pixel_data_d = adc_data[(DATA_BITS*ADC_BANKS)-1:0]; //still unclear/////////////////////////////////////////////////////////
                    end else begin
                        pixel_data_d = 0; //or some error code
                    end
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
                //if we've come to the max steps for the row, move to the next row
                if(row_cnt_q == ROWS-1 && step_cnt_q == STEPS_PER_ROW-1) begin
                    state_d = FRAME_DONE; //if this is the last row and last step, frame is done
                end else if (step_cnt_q == STEPS_PER_ROW-1) begin
                    step_cnt_d = 0; //reset step count for next row
                    row_cnt_d = row_cnt_q + 1; //move to next row
                    state_d = SELECT_ROW; //go back to select row for next row
                    line_done = 1; //signal that the line is done
                end else begin
                    step_cnt_d = step_cnt_q + 1; //move to next step for same row
                    state_d = START_CONVERT; //start next conversion for same row
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


assign timeout = (timeout_cnt_q >= ADC_TIMEOUT_CYCLES);
assign pixel_data = pixel_data_q;
assign pixel_valid = pixel_valid_q;


endmodule
