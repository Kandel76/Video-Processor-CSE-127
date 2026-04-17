//New ADC design based on 4 state-machine
module sar_adc (
    //global clk
    input logic [0:0] clk,
    //comparator input
    input logic [0:0] cmp_o,
    //from the scan controller
    input logic [0:0] read_en,
    //global reset
    input logic [0:0] reset_signal,
    //Sample Window from PWM
    input logic [0:0] valid_voltage,
    //approximated diode voltage
    output logic [3:0] adc_o,
    //send to scan controller, scan complete
    output logic [0:0] adc_done,
    //tells scan controller ready to scan,
    output logic [0:0] adc_ready
    
);
//State machine 
typedef enum logic [1:0] {
    IDLE = 2'b00, //Initial State, awaits Scan Controller and PWM inputs
    SAMPLE = 2'b01, //Samples cmp_o while Valid_voltage high
    UPDATE = 2'b10, //Updates adc code based on cmp_o
    SEND = 2'b11 //Sends code to the Scan Controller
} adc_fsm;

adc_fsm state_n, state; 

//Signals Used Internally
logic [3:0] adc_code; 
logic [0:0] cmp_i, voltage_signal; 
//FSM logic 
always_comb begin 
    state_n = state; 
    voltage_signal = ~valid_voltage; 
    case (state)
        IDLE: if (read_en && valid_voltage) begin 
            state_n = SAMPLE; 
        end
            else begin 
                state_n = IDLE;
            end
        SAMPLE: if (voltage_signal) begin 
            state_n = UPDATE;
        end
            else begin 
                state_n = SAMPLE; 
            end
        UPDATE: if ((cmp_i != 0) && (adc_code != 4'hf) && (valid_voltage)) begin 
            state_n = SAMPLE; 
        end
            else if ((cmp_i == 1) || (adc_code == 4'hf)) begin 
                state_n = SEND; 
            end
        SEND: state_n = IDLE; 
    default: state_n = IDLE; 
    endcase
end
always_ff @(posedge clk) begin 
    state <= state_n; 
    if (reset_signal) begin 
        adc_code <= '0; 
        adc_o <= '0; 
        cmp_i <= 1'b0; 
        adc_done <= 1'b0; 
        adc_ready <= 1'b1;
        state <= IDLE; 
    end
    else if (state == IDLE) begin 
        adc_code <= '0; 
        adc_o <= '0; 
        cmp_i <= 1'b0; 
        adc_done <= 1'b0; 
        adc_ready <= 1'b1;
    end
    else if (state == SAMPLE) begin 
        cmp_i <= cmp_o;
    end
    else if (state == UPDATE) begin 
        adc_code <= adc_code ++ cmp_i; 
    end
    else if (state == SEND) begin 
        adc_done <= 1'b1; 
        adc_o <= adc_code; 
    end
end