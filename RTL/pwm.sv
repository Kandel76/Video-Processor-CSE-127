module pwm #
(
    parameter N = 6               // resolution
)
(
    input  logic        clk,     // system clock
    input  logic        rst_n,   //sync  reset, active low
    input  logic [N-1:0] duty_threshold,   // duty cycle
    
    output logic         pwm_out
);

    //D - next state
    //Q - current state
    logic [N-1:0] count_d, count_q;
    logic pwm_d, pwm_q;

    always_comb begin
        count_d = count_q + 1;
        
        if(count_q < duty_threshold) begin
            pwm_d = 1;
        end else begin
            pwm_d = 0;
        end

    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            count_q <= 0;
            pwm_q   <= 0;
        end else begin
            count_q <= count_d;
            pwm_q   <= pwm_d;
        end
    end

assign pwm_out = pwm_q;

endmodule



