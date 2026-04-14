//this design assumes adc outputs 1 code at a time (320 adcs)
module sar_adc (
    //global clk
    input logic [0:0] adc_clk,
    //comparator input
    input logic [0:0] cmp_o,
    //from the scan controller
    input logic [0:0] read_en,
    //global reset
    input logic [0:0] reset_signal,
    //app diode voltage
    output logic [3:0] adc_o,
    //This will ensure photodiode voltage is captured and tested without changes
    output logic [0:0] hold_signal,
    //send to scan controller, scan complete
    output logic [0:0] adc_done,
    //tells scan controller ready to scan,
    output logic [0:0] adc_ready
    
);
//Some states exist to allow for appropiate timing
typedef enum logic [2:0]{
    IDLE        =3'd0,  //Scan controller is off (completed scan)
    VIN_HOLD    =3'd1, //hold the diode voltage for a cycle before transitioning and setup the adc,
    PWM _HOLD   =3'd2, //hold code to allow PWM signal to settle
    CODE_UPDATE =3'd3, //checks comparator and decides whether to continue ramp
    CODE_STORE  =3'd4 //store the code and move back to idle

} adc_fsm;

adc_fsm state, state_n; 
//4-bit code, tells us the photodiode expected voltage (internal adc_o)
logic [3:0] adc_code; 

//Will need a counter to wait a few cycles (this will end up being the pwms sample rate)
//for now fixed params for testing 
logic [5:0] hold, code_hold;
localparam logic [5:0] HOLD_CYCLES   = 6'd6;
localparam logic [5:0] SETTLE_CYCLES = 6'd32;

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
        //this state waits HOLD_CYCLES cycles to allow signal to propagate through chip (diode charge)
        VIN_HOLD: if (hold == (HOLD_CYCLES - 6'd1)) begin 
            state_n = PWM_HOLD; 
            end
        //wait SETTLE_CYCLES cycles before sampling comparator
        PWM_HOLD: if (code_hold == (SETTLE_CYCLES - 6'd1)) begin 
            state_n = CODE_UPDATE;
        end

        // With this new pwm logic, we now exit whenever the comp returns a 0, or we've reached the the final code possible
        CODE_UPDATE: if ((cmp_o == 1'b0) || (adc_code == 4'hF)) begin
            state_n = CODE_STORE; 
        end
        else begin 
            state_n = PWM_HOLD; 
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
        hold <= '0; 
        code_hold <= '0; 
        state <= IDLE;  
        adc_done <= 1'b0;
        hold_signal <= 1'b0;
        adc_o <= '0;
        adc_ready <= 1'b0;
    end
    else if (state == IDLE) begin 
        adc_code <= '0; 
        hold <= '0; 
        code_hold <= '0;
        hold_signal <= 1'b0;
        adc_ready <= 1'b1;
        adc_done <= 1'b0;
    end
    //we want the hold_signal to be high until we are done with the code generation
    else if (state == VIN_HOLD) begin  
        adc_ready <= 1'b0;
        if (state_n == PWM_HOLD) begin 
            hold <= 0; 
        end
        else begin 
            hold <= hold + 1; 
            hold_signal <= 1'b1;
        end
    end
    else if (state == PWM_HOLD) begin 
        //code no longer sent to cmp, but we need to wait pwm cycles now
        if (state_n == CODE_UPDATE) begin 
            code_hold <= 0; 
        end
        else begin 
            code_hold <= code_hold + 1; 
        end
    end
    else if (state == CODE_UPDATE) begin 
        // We now incrmement our code until cmp_o returns a 0
        if ((cmp_o == 1'b1) && (adc_code != 4'hF)) begin
            adc_code <= adc_code + 1'b1;
        end
    end
    else if (state == CODE_STORE) begin 
        adc_o <= adc_code; 
        adc_done <= 1'b1;  
    end
end 
endmodule
