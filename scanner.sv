module scan_controller #(
    parameter int ROWS = 240,
    parameter int COLS = 320,
    parameter int ADC_BANKS = 4,
    parameter int DATA_BITS = 4, 
    parameter int ADC_TIMEOUT_CYCLES = 20,
)(
    //inputs
    input logic clk,
    input logic rst_n,   //ACTIVE LOW
    input logic adc_done,   //signals when all ADC conversions for the current step are done
    input logic [(DATA_BITS*ADC_BANKS)-1:0] adc_data,  //data from the ADC 
    input logic pixel_ready,  //ready signal from array, pixel data can be used
    input logic frame_start, //FOR ANOTHER MODULE to start a new frame (later used to frame rate control)
    
    //outputs
    output logic                              frame_end  //signals when the entire fram is complete
    output logic [ROWS-1:0]           row_enable,    //should this be one hot or indexed for row_en?
    output logic [$clog2(ADC_BANKS)-1:0]      bank_sel, //which bank to start conversion on
    output logic                              adc_start, //start conversion for the specifc adc
    output logic [DATA_BITS-1:0]              pixel_data, 
    output logic [$clog2(ROWS)-1:0]           pixel_row, //current row being output -- used for mapping to pixel array
    output logic [$clog2(COLS)-1:0]           pixel_col, //current col being output -- used for mapping to pixel array
    output logic                              pixel_valid  //used later for mapping
    output logic                              pixel_reset //global reset for pixels at the start of each frame
);
    
    localparam int STEPS_PER_ROW = COLS / (ADC_BANKS);  //strides

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
    logic [$clog2(ROWS)-1:0]     row_cnt;   //row counter
    logic [$clog2(STEPS_PER_ROW)-1:0] step_cnt;  //step counter for columns
    logic [$clog2(ADC_TIMEOUT_CYCLES)-1:0] timeout_cnt; //timeout counter for ADC


    
    // ff for states and counters
    always_ff @(posedge clk) begin
        if (!rst_n) begin //ACTIVE LOW RESET
            state_q <= IDLE;
            row_cnt <= 0;
            step_cnt <= 0;
            timeout_cnt <= 0;

        end else begin
            state_q <= state_d;
            
            case (state_q)
                //reset counters at the start of a new frame or when idle
                IDLE: begin
                    row_cnt <= 0;
                    step_cnt <= 0;
                    timeout_cnt <= 0;
                end
                NEXT_ROW: begin
                    //if there is more rows to process +1
                    if (row_cnt < ROWS-1) begin
                        row_cnt <= row_cnt + 1;
                        //start from the first step
                        step_cnt <= 0;
                    end else begin
                        row_cnt <= 0;
                        step_cnt <= 0;
                    end
                end
                //go to next step of col
                OUTPUT_PIXELS: begin
                    step_cnt <= step_cnt + 1;
                end
            endcase
        end
    end
    

// driving d_ff
    always_comb begin
        // Default outputs
        state_d = state_q; //hold state by default
        frame_done = 0;
        row_enable = 0;
        pixel_col = 0;
        adc_start = 0;
        pixel_valid = 0;
        pixel_row = row_cnt;
        pixel_data = 0;
        pixel_reset = 0;
        
        case (state_q)
            IDLE: begin

                //wait for a flag to start the next frame
                if (frame_start) begin
                    state_d = RESET_PIXELS; 
                end

            end
            
            RESET_PIXELS: begin

                // global reset of pixels
                pixel_reset = 1;
                state_d = INTEGRATE;

            end
            
            INTEGRATE: begin


                //wait a specifc # cycles to integrate pixels


                 
                state_d = SELECT_ROW;
            end
            
            SELECT_ROW: begin

                row_enable[row_cnt] = 1; //enable current row
                state_d = START_CONVERT;

            end
            
            START_CONVERT: begin

                row_enable[row_cnt] = 1; //keep row enabled
                pixel_col = step_cnt * ADC_BANKS; //select starting column for this step
                adc_start = 1;  // Start all banks
                state_d = WAIT_CONVERT;

            end
            
            WAIT_CONVERT: begin

                pixel_col = step_cnt * ADC_BANKS; //keep column selected
                
                if (adc_done || timeout) begin
                    state_d = OUTPUT_PIXELS;
                end

            end
            
            OUTPUT_PIXELS: begin

                row_enable[row_cnt] = 1;
                
                if (adc_done && pixel_ready) begin
                    pixel_valid = 1'b1;
                end else begin
                    pixel_valid = 1'b0;
                end
                
                end

            
            NEXT_ROW: begin

                // line_done = 1;
                if (row_cnt == ROWS-1) begin
                    state_d = FRAME_DONE;
                end else begin
                    state_d = SELECT_ROW;
                end

            end
            
            FRAME_DONE: begin

                frame_done = 1;
                state_d = IDLE;
            end

            DEFAULT: begin

                state_d = IDLE;

            end

        endcase
        
    end

//implement timeout logic
//ff and comb logic


endmodule
