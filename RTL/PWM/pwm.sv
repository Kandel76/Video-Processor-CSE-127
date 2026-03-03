module pwm #
(
    parameter N = 6               // resolution
)
(
    input  logic          clk,     // system clock (assume 25MHz)
    input  logic          rst_n,   //sync  reset, active low
    input  logic  [N-1:0] duty_threshold,   // duty cycle
    input  logic  [N-1:0] period,
    
    output logic         pwm_out
);


//equations
// f_pwm = (f_clk / period)
// period = (f_clk / f_pwm)
// Duty = duty_threshold / period

    //D - next state
    //Q - current state
    logic [N-1:0] count_d, count_q;
    logic pwm_d, pwm_q;

    always_comb begin
	    count_d = count_q;
	    if (period == 0) begin
		    count_d = 0;
	    end else if (count_q == period - 1) begin
		    count_d = 0;
	    end else begin
		    count_d = count_q + 1;
	    end
	    // clamp?
	    if (duty_threshold >= period)
		    pwm_d = 1'b1;
	    else    
		    pwm_d = (count_q < duty_threshold);
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



