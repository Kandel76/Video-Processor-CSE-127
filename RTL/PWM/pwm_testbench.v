`timescale 1ns / 1ps



module tb_pwm;

  localparam N = 6;

  // DUT signals
  logic clk;
  logic rst_n;
  logic [N - 1 : 0] duty_threshold;
  logic [N - 1 : 0] period;
  logic pwm_out;

  // DUT instantiate
  pwm #(.N(N))
      dut(.clk(clk),
          .rst_n(rst_n),
          .duty_threshold(duty_threshold),
          .period(period),
          .pwm_out(pwm_out));

  //  every 20ns -- 25MHz
  initial
    clk = 0;
  always
    #20 clk = ~clk;

  // run_periods: advance the simulation for a given number of PWM periods
  // waits on clk posedges; useful for letting the DUT operate
  // after signals like period or duty_threshold change.
  task run_periods
      (input int num_periods);
    int i;
    for (i = 0; i < num_periods * period; i++) begin
      @(posedge clk);
    end
  endtask

  // measure_duty: sample pwm_out over one full period and count
  // how many clock cycles the output stays high. The result
  // is returned in the high_cycles output argument.
  task measure_duty
      (output int high_cycles);
    int i;
    high_cycles = 0;
    // assume period is stable
    for (i = 0; i < period; i++) begin
      @(posedge clk);
      if (pwm_out)
        high_cycles++;
    end
  endtask

  // check_duty: wrapper around measure_duty that compares the result
  //              to an expected value and prints pass/fail messages.
  //              The "name" string tags the check for easier debugging.
  task check_duty
      (string name,
       int expected);
    int high_cycles;
    measure_duty(high_cycles);
    if (high_cycles !== expected) begin
      $error("%s FAILED: expected high_cycles = %0d, got %0d", name, expected,
             high_cycles);
    end else begin
      $display("%s PASSED: high_cycles = %0d", name, high_cycles);
    end
  endtask

  // TEST

  initial begin

    integer expected;

    $dumpfile("pwm_waveform.vcd");
    $dumpvars(0, tb_pwm);

    // Defaults
    duty_threshold = '0;
    period = 10;
    rst_n = 0;

    // reset
    $display("TEST: reset");
    repeat (5) @(posedge clk)
      ;
    rst_n = 1;
    @(posedge clk);
    period = 16;
    duty_threshold = 0;
    check_duty("Reset + 0% duty", 0);

    // 0% duty
    $display("TEST: 0%% duty");
    period = 16;
    duty_threshold = 0;
    check_duty("0% duty", 0);

    // 100% duty (duty_threshold >= period)
    $display("TEST: 100%% duty");
    period = 16;
    duty_threshold = 16; // >= period => 100% duty
    expected = period;   // all cycles high
    check_duty("100% duty", expected);

    // Mid duty (e.g., 50%)
    $display("TEST: mid duty (50%%)");
    period = 16;
    duty_threshold = 8; // 8/16 = 50%
    expected = 8;
    check_duty("Mid duty (50%)", expected);

    // Small duty (e.g., ~6%)
    $display("TEST: small duty");
    period = 32;
    duty_threshold = 2; // 2/32 = 6.25%
    expected = 2;
    check_duty("Small duty", expected);

    // Large duty (just below 100%)
    $display("TEST: large duty");
    period = 32;
    duty_threshold = 31; // 31/32 ~ 97%
    expected = 31;
    check_duty("Large duty", expected);

    // Counter wraparound
    //    Check repeated periods produce same duty
    $display("TEST: counter wraparound");
    period = 10;
    duty_threshold = 5;
    expected = 5;

    // Let it run for a few periods, checking consistency
    check_duty("Wraparound period 1", expected);
    check_duty("Wraparound period 2", expected);
    check_duty("Wraparound period 3", expected);

    // Duty threshold change during operation
    $display("TEST: duty change during operation");
    period = 16;
    duty_threshold = 4; // 25%
    expected = 4;
    check_duty("Duty change - first (25%)", expected);
    // Change duty while running
    duty_threshold = 12; // 75%
    expected = 12;
    check_duty("Duty change - second (75%)", expected);

    // Multiple period consistency
    $display("TEST: multiple periods");

    // period = 8 -- 25% duty
    period = 8;
    duty_threshold = 2;
    expected = 2;
    check_duty("Period=8, 25% duty", expected);

    // period = 20 - 50% duty
    period = 20;
    duty_threshold = 10;
    expected = 10;
    check_duty("Period=20, 50% duty", expected);

    // period = 1 (edge case)
    // count_q goes 0..0, duty_threshold < period => either 0 or clamped
    period = 1;
    duty_threshold = 0; // 0/1 = 0% duty
    expected = 0;
    check_duty("Period=1, 0% duty", expected);

    // period = 0 (edge case handled in DUT)
    // DUT forces pwm_out = 0 in this case
    $display("TEST: period = 0 edge case");
    period = 0;
    duty_threshold = 10;

    // period=0, measure_duty is not meaningful; just sample a few cycles.
    repeat (10) @(posedge clk)
      ;
    if (pwm_out !== 1'b0) begin
      $error("Period=0 edge case FAILED: pwm_out should stay 0");
    end else begin
      $display("Period=0 edge case PASSED: pwm_out is 0");
    end

    $display("All tests completed.");
    $finish;
  end
endmodule
