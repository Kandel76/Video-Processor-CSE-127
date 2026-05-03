//New ADC design based on 5 state-machine
module sar_adc (
    //global clk
    input logic [0:0] clk,
    //comparator input
    input logic [0:0] cmp_o,
    //from the scan controller
    input logic [0:0] read_en,
    //global reset
    input logic [0:0] reset_signal,
    //row reset
    input logic [0:0] adc_reset,
    //Sample Window from Ramp
    input logic [0:0] valid_voltage,
    //approximated diode voltage
    output logic [3:0] adc_o,
    //send to scan controller, scan complete
    output logic [0:0] adc_done,
    //tells scan controller ready to scan,
    output logic [0:0] adc_ready,
    //output to inform the Ramp Controller we have finished comparing
    output logic [0:0] comp_done
    
);
//State machine 
typedef enum logic [2:0] {
    IDLE = 3'b000, //Initial State, awaits Scan Controller and PWM inputs
    SAMPLE = 3'b001, //Samples cmp_o while Valid_voltage high
    UPDATE = 3'b010, //Updates adc code based on cmp_o
    WAIT = 3'b011, //Waits for the next valid_voltage high
    SEND = 3'b100 //Sends code to the Scan Controller
} adc_fsm;

adc_fsm state_n, state; 

//Signals Used Internally
logic [3:0] adc_code; 
logic [0:0] cmp_i, voltage_invalid; 
//FSM logic 
always_comb begin 
    state_n = state; 
    voltage_invalid = ~valid_voltage; 
    case (state)
        IDLE: if (read_en && valid_voltage) begin 
            state_n = SAMPLE; 
        end
            else begin 
                state_n = IDLE;
            end
        SAMPLE: if (voltage_invalid) begin 
            state_n = UPDATE;
        end
            else begin 
                state_n = SAMPLE; 
            end
        UPDATE: if ((cmp_i == 0) || (adc_code == 4'hf)) begin 
                state_n = SEND; 
            end
            else begin 
                state_n = WAIT; 
            end
        WAIT: if (valid_voltage) begin 
            state_n = SAMPLE; 
            end
            else begin 
                state_n = WAIT; 
            end 
        SEND: state_n = SEND; 
        default: state_n = IDLE; 
    endcase
end
always_ff @(posedge clk or posedge reset_signal or posedge adc_reset) begin
    if (reset_signal) begin
        adc_code <= '0;
        adc_o <= '0;
        cmp_i <= 1'b0;
        adc_done <= 1'b0;
        adc_ready <= 1'b1;
        comp_done <= 1'b0;
        state <= IDLE;
    end 
    else if (adc_reset) begin
        adc_code        <= '0;
        cmp_i           <= 1'b0;
        adc_done        <= 1'b0;
        adc_ready       <= 1'b1;
        comp_done       <= 1'b0;
        state           <= IDLE;
    end 
    else begin
        state <= state_n; 
        // Default outputs
        adc_ready <= 1'b0;
        adc_done  <= 1'b0;
        comp_done <= 1'b0;
        if (state == IDLE) begin
            adc_code        <= '0;
            cmp_i           <= 1'b0;
            adc_ready       <= 1'b1;
        end
        else if (state == SAMPLE) begin 
            cmp_i <= cmp_o;
        end
        else if (state == UPDATE) begin 
            comp_done <= 1'b1;
            adc_code <= adc_code + {3'b0, cmp_i}; 
        end
        else if (state == SEND) begin 
            adc_done <= 1'b1; 
            adc_o <= adc_code; 
        end
    end
end
endmodule