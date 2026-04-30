module ramp_controller #(parameter int ramp_time = 775)(
    //global clock
    input [0:0] clk,
    //global reset
    input [0:0] global_reset,
    //from adc, tells us when we are done comparing
    input logic [0:0] comp_done, 
    //from the scan controller, 
    input logic [0:0] adc_start,
    //to the pwm module, the duty cycle to use
    output logic [3:0] duty_cycle,
    //to the adc, resets interal counters for next code generation
    output logic [0:0] reset_adc,
    //allows the adc to sample voltage we expect to be accurate
    output logic [0:0] valid_voltage,
    //high during the final ramp step so scanner skips RESET_PIXELS
    output logic [0:0] last_step

);
//Ramp counter to ensure we have waited the necessary time for the PWM to settle
logic [$clog2(ramp_time)-1:0] ramp_counter; 
logic [0:0] ramp_done; 

//State machine 
typedef enum logic [1:0] {
    IDLE = 2'b00, //Initial State, waits for adc_start 
    VOLTAGE_RAMP = 2'b01, //will ramp up for 775 cycles for now
    WAIT = 2'b10, //sends a signal for the adc to sample, waits for comp_done
    FINISH = 2'b11 //once we have done this 16 times we end the row 
} ramp_fsm;

ramp_fsm state, state_n; 

always_comb begin 
    state_n = state;
    //done check for the ramp counter
    ramp_done = (ramp_counter == ramp_time-1); 

    case (state)
        IDLE: if (adc_start) begin 
            state_n = VOLTAGE_RAMP;
            end
            else begin 
            state_n = IDLE; 
            end
        VOLTAGE_RAMP: if (ramp_done) begin 
            state_n = WAIT;
            end
            else begin 
                state_n = VOLTAGE_RAMP; 
            end
        WAIT: if (comp_done && duty_cycle == 4'b1111) begin 
            state_n = FINISH; 
            end
            else if (comp_done) begin 
            state_n = VOLTAGE_RAMP;
            end
            else begin 
                state_n = WAIT; 
            end
        FINISH: state_n = IDLE; 
        default: state_n = IDLE; 
        
    endcase
end

assign last_step = (state == WAIT) && (duty_cycle == 4'b1111);

always_ff @(posedge clk or posedge global_reset) begin
    if (global_reset) begin 
        ramp_counter <= '0;
        duty_cycle <= '0; 
        valid_voltage <= '0; 
        reset_adc <= '0; 
        state <= IDLE;
    end
    else begin 
        state <= state_n; 
        valid_voltage <= '0;
        reset_adc <= '0;
        if (state == IDLE) begin 
            ramp_counter <= '0;
            duty_cycle <= '0; 
        end
        else if (state == VOLTAGE_RAMP) begin 
            if (state_n == WAIT) begin
                ramp_counter <= '0;
                valid_voltage <= '1;
            end
            else begin
                ramp_counter <= ramp_counter + 1'b1;
            end
        end
        else if (state == WAIT) begin 
            if (state_n == VOLTAGE_RAMP) begin
                duty_cycle <= duty_cycle + 1'b1; 
            end
        end
        else if (state == FINISH) begin 
            reset_adc <= '1;
        end

    end 
end

endmodule 
