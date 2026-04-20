module pwm
    #(parameter N = 4 // resolution
    )
    (input logic clk,
     // system clock (assume 25MHz)
     input logic rst_n,
     // sync  reset, active low
     input logic [N - 1 : 0] duty_cycle,
     // duty cycle
     input logic [N - 1 : 0] period,

     output logic pwm_out,
     
     output logic period_start_out
     //one cycle pulse when the period starts (counter resets to 0 for a clean start)
     // so no mixing of duty cycle
     );

  // equations
  //  f_pwm = (f_clk / period)
  //  period = (f_clk / f_pwm
  //  Duty = duty_cycle / period

  // D - next state
  // Q - current state
  logic [N - 1 : 0] count_d, count_q;
  logic pwm_d, pwm_q;

  always_comb begin
    // defaults
    count_d = count_q;
    pwm_d = pwm_q;

    if (period == 0) begin
      count_d = 0;
      pwm_d = 1'b0; // defined behavior when period = 0
    end else begin
      // counter update
      if (count_q == period - 1) begin
        count_d = 0;
      end else begin
        count_d = count_q + 1;
      end

      // duty / clamp
      if (duty_cycle >= period) begin
        pwm_d = 1'b1; // treat >= as 100% duty
      end else begin
        pwm_d = (count_q < duty_cycle);
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      count_q <= 0;
      pwm_q <= 0;
    end else begin
      count_q <= count_d;
      pwm_q <= pwm_d;
    end
  end

  assign period_start_out = (count_q == 0) && (period != 0); 
  assign pwm_out = pwm_q;
endmodule
