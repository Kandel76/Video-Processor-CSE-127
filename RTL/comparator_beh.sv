// Behavioral stand-in for comparator.sv (GF180 cell-based).
// Same port interface; replaces it during simulation.
// Output is high when v_inp > v_inm (ramp has not yet reached pixel voltage).
// Registered on posedge clk to match the latching behavior of the SR-latch original.
module comparator (
    input  logic clk_i,
    input  logic v_inp,   // pixel threshold
    input  logic v_inm,   // shared ramp (pwm_out)
    output logic q_o,
    output logic q_invo
);
    always_ff @(posedge clk_i)
        q_o <= v_inp & ~v_inm;

    assign q_invo = ~q_o;
endmodule
