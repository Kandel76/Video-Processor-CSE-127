module ramp_controller #(parameter int adc_wait_cycles = 4,
parameter int ramp_time = 775,
parameter int voltage = 4,
parameter int pulse = 4)(
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
    VOLTAGE_VALID = 2'b10, //sends a signal for the adc to sample, waits for comp_done
    FINISH = 2'b11 //once we have done this 16 times we end the row 
} ramp_fsm;

ramp_fsm state, state_n; 

//Counter to ensure all adcs have settled before moving to the next duty cycle
logic [$clog2(adc_wait_cycles+1)-1:0] adc_wait;
logic [0:0] adc_wait_done; 
//counter to make valid_voltage high for exactly `voltage` cycles
logic [$clog2(voltage+1)-1:0] voltage_sample_now;
logic [0:0] valid_high; 
//counter to pulse reset signal 
logic [$clog2(pulse)-1:0] pulse_wait;
logic [0:0] pulse_wait_done; 


always_comb begin 
    state_n = state;
    //done checks for the ramp, adc_wait, and pulse_wait counters
    ramp_done = (ramp_counter == ramp_time-1); 
    adc_wait_done = (adc_wait == adc_wait_cycles-1); 
    pulse_wait_done = (pulse_wait == pulse-1); 

    //this will make valid_voltage high whilst voltage_sample_now is less than voltage
    valid_high = (state == VOLTAGE_VALID) && (voltage_sample_now < voltage);

    case (state)
        IDLE: if (adc_start) begin 
            state_n = VOLTAGE_RAMP;
            end
            else begin 
            state_n = IDLE; 
            end
        VOLTAGE_RAMP: if (ramp_done) begin 
            state_n = VOLTAGE_VALID;
            end
            else begin 
                state_n = VOLTAGE_RAMP; 
            end
        VOLTAGE_VALID: if (duty_cycle == 4'b1111) begin 
            state_n = FINISH; 
            end
            else if (comp_done && adc_wait_done) begin 
            state_n = VOLTAGE_RAMP;
            end
            else begin 
                state_n = VOLTAGE_VALID; 
            end
        FINISH: if (pulse_wait_done) begin 
            state_n = IDLE; 
            end
            else begin 
                state_n = FINISH; 
            end
        default: state_n = IDLE; 
        
    endcase
end

assign last_step = (state == VOLTAGE_VALID) && (duty_cycle == 4'b1111);

always_ff @(posedge clk or posedge global_reset) begin
    if (global_reset) begin 
        ramp_counter <= '0;
        adc_wait <= '0; 
        pulse_wait <= '0; 
        voltage_sample_now <= '0; 
        duty_cycle <= '0; 
        valid_voltage <= '0; 
        reset_adc <= '0; 
        state <= IDLE;
    end
    else begin 
        state <= state_n; 
        // Default low each cycle; only assert during the intended pulse window.
        valid_voltage <= '0;
        reset_adc <= '0;
        if (state == IDLE) begin 
            ramp_counter <= '0;
              adc_wait <= '0; 
            pulse_wait <= '0; 
            voltage_sample_now <= '0; 
            duty_cycle <= '0; 
        end
        else if (state == VOLTAGE_RAMP) begin 
            if (state_n == VOLTAGE_VALID) begin
                ramp_counter <= '0;
            end
            else begin
                ramp_counter <= ramp_counter + 1'b1;
            end
            adc_wait <= '0; 
            voltage_sample_now <= '0; 
        end
        else if (state == VOLTAGE_VALID) begin 
            valid_voltage <= valid_high;
            if (comp_done && !adc_wait_done) begin 
                adc_wait <= adc_wait + 1'b1; 
            end
            if (state_n == VOLTAGE_RAMP) begin
                duty_cycle <= duty_cycle + 1'b1; 
            end
            if (voltage_sample_now < voltage) begin
                voltage_sample_now <= voltage_sample_now + 1'b1;
            end
        end
        else if (state == FINISH) begin 
            reset_adc <= '1;
            if (!pulse_wait_done) begin
                pulse_wait <= pulse_wait + 1'b1; 
            end
        end

    end 
end

endmodule 
