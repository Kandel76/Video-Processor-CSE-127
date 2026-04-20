module ramp_controller #(parameter int voltage_sample_rate = 10, 
parameter int ramp_time = 775)(
    //global clock
    input [0:0] clk,
    //global reset
    input [0:0] global_reset,
    //from adc, tells us when we are done comparing
    input [0:0] comp_done, 
    //
    input [0:0] adc_start,
    //
    output [3:0] duty_cycle,
    //
    output [0:0] reset_adc,
    //
    output [$clog2(voltage_sample_rate)-1:0] valid_voltage

);
//
logic [$clog2(ramp_time)-1:0] ramp_counter; 

//State machine 
typedef enum logic [1:0] {
    IDLE = 2'b00, //Initial State, waits for adc_start 
    VOLTAGE_RAMP = 2'b01, //will ramp up for 775 cycles for now
    VOLTAGE_VALID = 2'b10, //sends a signal for the adc to sample, waits for comp_done
    FINISH = 2'b11 //once we have done this 16 times we end the row 
} ramp_fsm;

ramp_fsm state, state_n; 

endmodule 