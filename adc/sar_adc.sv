//this design assumes adc outputs 1 code at a time
module sar_adc #(
    parameter NUM_ROWS = 240
    parameter NUM_COLS = 320
)(
    input logic [0:0] adc_clk,
    input logic [0:0] cmp_o,
    input logic [0:0] read_en,
    input logic [0:0] reset_signal,
    //should then tell us which diode to choose based on a mux design
    input logic [7:0] diode_row
    output logic [3:0] adc_o,
    //This will ensure photodiode voltage is captured and tested without changes
    output logic [0:0] hold_signal
    
)
//Extra states (less optimal), however I wish to mitigate setup/hold time violations
typedef enum logic [2:0]{
    IDLE        =3'd0,  //Scan controller is off
    VIN_HOLD    =3'd1, //hold the diode voltage for a cycle before transitioning and setup the adc,
    CODE_SEND   =3'd2, //give the dac the 4-bit code
    COMPARE     =3'd3, //compares returned bit with test vit
    CODE_STORE  =3'd4 //after 4 iterations we get here, store the code and move back to idle/

} adc_fsm;

adc_fsm state, state_n; 
//4-bit code, tells us the photodiode expected voltage
logic [3:0] adc_code; 

logic [1:0] bit_idx; 
//Will need a counter to wait a few cycles, unsure if its better to use 2 or 1, for now will assume 2
logic [2:0] hold, code_hold

always_comb begin
    state_n = state; 
    case (state)

        IDLE: if (read_en) begin 
            state_n = VIN_HOLD; 
            else begin 
                state_n = IDLE;
            end
        end
        VIN_HOLD: if (cycle_wait[2] && cycle_wait[1]) begin 
            state_n = CODE_SEND; 
            end
            else if (reset_signal) begin 
                state_n = IDLE; 
            end

        CODE_SEND: state_n = COMPARE;

        COMPARE: if(bit_idx == 0) begin 
            state_n = CODE_STORE;
        end
        else if (reset_signal) begin 
            state_n = IDLE; 
        end
        else begin 
            state_n = CODE_SEND; 
        end
        CODE_STORE: state_n = IDLE; 
    default: state_n = IDLE: 
    endcase
end

always_ff @(posedge adc_clk) begin 
    if (reset_signal) begin 
        adc_code <= '0;
        //mux bit will also be all zeros
        //should set back to the MSB
        bit_idx <= 11;  
    end
    if (state == VIN_HOLD) begin 
        hold <= hold+ 1; 
    end
    else hold <= '0; 
end 