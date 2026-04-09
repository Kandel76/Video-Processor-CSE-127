//this design assumes adc outputs 1 code at a time
module sar_adc (
    input logic [0:0] adc_clk,
    //once comparator is integrated, this wont be an input
    input logic [0:0] cmp_o,
    input logic [0:0] read_en,
    input logic [0:0] reset_signal,
    //should then tell us which diode to choose based on a mux design
    output logic [3:0] adc_o,
    //This will ensure photodiode voltage is captured and tested without changes
    //currently still unsure on how this signal will be generated on chip.
    output logic [0:0] hold_signal,
    output logic [0:0] adc_done
    
);
//Some states exist to allow for appropiate timing
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

logic [1:0] bit_index; 
//Will need a counter to wait a few cycles
logic [5:0] hold, code_hold;
logic [0:0] dac_code_sent; 
//counter to keep track of comparison cycle
logic [1:0] comp_cycle;
//keep track of diode
logic [7:0] diode_row;
//Store the DAC code
logic [3:0] adc_dac_o;


// DAC needs code same cycle, so it needs to be outside always blocks.
assign adc_dac_o = (state == CODE_SEND) ? (adc_code | (4'b1 << bit_index)) : adc_code;

//FSM state logic
always_comb begin
    state_n = state; 
    case (state)

        IDLE: if (read_en) begin 
            state_n = VIN_HOLD; 
        end
            else begin 
                state_n = IDLE; 
            end
        //this state should wait 6 cycles
        VIN_HOLD: if (hold[2] && hold[1]) begin 
            state_n = CODE_SEND; 
            end
        //we may find ourselves waiting here for longer than expected.
        CODE_SEND: if (code_hold[5]) begin 
            state_n = COMPARE;
        end

        COMPARE: if (comp_cycle == 2'b11) begin 
            state_n = CODE_STORE; 
        end
        else begin 
            state_n = CODE_SEND; 
        end
        CODE_STORE: state_n = IDLE; 
    default: state_n = IDLE; 
    endcase
end

//What we do in each state
always_ff @(posedge adc_clk) begin 
    state <= state_n;
    if (reset_signal) begin 
        adc_code <= '0;
        //mux bit will also be all zeros
        //should set back to the MSB
        comp_cycle <= '0;  
        dac_code_sent <= '0; 
        hold <= '0; 
        code_hold <= '0; 
        bit_index <= 2'b11; 
        state <= IDLE;  
        diode_row <= 8'b00000001; 
        adc_done <= 1'b0;
        hold_signal <= 1'b0;
    end
    else if (state == IDLE) begin 
        adc_code <= '0; 
        comp_cycle <= '0; 
        dac_code_sent <= '0;
        hold <= '0; 
        code_hold <= '0;
        bit_index <= 2'b11;
        adc_done <= 1'b0;
        hold_signal <= 1'b0;
    end
    else if (state == VIN_HOLD) begin 
        if (state_n == CODE_SEND) begin 
            hold <= 0; 
            hold_signal <= 1'b0;
        end
        else begin 
            hold <= hold + 1; 
            hold_signal <= 1'b1;
        end
    end
    else if (state == CODE_SEND) begin 
        //comp will get code here (no comp module nowhere to sound as of now)
        if (state_n == COMPARE) begin 
            code_hold <= 0; 
        end
        else begin 
            code_hold <= code_hold + 1; 
        end
        adc_code[bit_index] <= 1'b1;
    end
    else if (state == COMPARE) begin 
        if (cmp_o == 1) begin 
            adc_code[bit_index] <= 1'b1; 
        end
        else begin 
            adc_code[bit_index] <= 1'b0; 
        end
        bit_index <= bit_index - 1; 
        comp_cycle <= comp_cycle + 1; 
    end
    if (state == CODE_STORE) begin 
        adc_o <= adc_code; 
        diode_row <= diode_row + 1;
        adc_done <= 1'b1;  
    end
end 
endmodule
