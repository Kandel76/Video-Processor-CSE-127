`timescale 1ns/1ps

module pwm_tb;

    parameter N = 6;

    logic clk;
    logic rst_n;
    logic [N-1:0] duty_threshold;
    logic [N-1:0] period;
    logic pwm_out;

    // Instantiate DUT
    pwm #(.N(N)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .duty_threshold(duty_threshold),
        .period(period),
        .pwm_out(pwm_out)
    );

    // 25 MHz clock (40ns period)
    initial clk = 0;
    always #20 clk = ~clk;

    // Waveform dump
    initial begin
        $dumpfile("pwm.vcd");
        $dumpvars(0, pwm_tb);
    end


    initial begin
        rst_n = 0;
        duty_threshold = 0;
        period = 0;

        #100;
        rst_n = 1;

        #40;
        period = 20;
        duty_threshold = 5; // 25%
        #10000;

        // 50%
        period = 20;
        duty_threshold = 10;
        #100000;

        period = 20;
        duty_threshold = 15; // 75%
        #100000;

        $display("Simulation finished");
        $finish;
    end

endmodule