module comparator (
    input [0:0] clk_i,
    input [0:0] v_inp,
    input [0:0] v_inm,
    output [0:0] q_o,
    output [0:0] q_invo
);
    //inverted signal to drive comparator NOR3's
    wire clk_inv;

    //internal latch nodes
    wire norA_o;
    wire norB_o;
    wire nandA_o;
    wire nandB_o;
    wire nandA_inv;
    wire nandB_inv;

    //invert clk
    (* dont_touch = "true" *) gf180mcu_as_sc_mcu7t3v3__inv_2 u_inv_clk (
        .A(clk_i[0]),
        .Y(clk_inv)
    );
    
    //NOR3A
    //assign norA_o = ~(v_inp | clk_inv | norB_o);
    (* dont_touch = "true" *) gf180mcu_as_sc_mcu7t3v3__nor3_2 u_norA (
        .A(v_inp[0]),
        .B(clk_inv),
        .C(norB_o),
        .Y(norA_o)
    );
    
    //NOR3B
    //assign norB_o = ~(v_inm | clk_inv | norA_o);
    (* dont_touch = "true" *) gf180mcu_as_sc_mcu7t3v3__nor3_2 u_norB (
        .A(v_inm[0]),
        .B(clk_inv),
        .C(norA_o),
        .Y(norB_o)
    );

    //NAND3A
    //assign nandA_o = ~(v_inm & clk_i & nandB_o);
    (* dont_touch = "true" *) gf180mcu_as_sc_mcu7t3v3__nand3_2 u_nandA (
        .A(v_inm[0]),
        .B(clk_i[0]),
        .C(nandB_o),
        .Y(nandA_o)
    );

    //NAND3A_INV
    (* dont_touch = "true" *) gf180mcu_as_sc_mcu7t3v3__inv_2 u_inv_nandA (
        .A(nandA_o),
        .Y(nandA_inv)
    );

    //NAND3B
    //assign nandB_o = ~(v_inp & clk_i & nandA_o);
    (* dont_touch = "true" *) gf180mcu_as_sc_mcu7t3v3__nand3_2 u_nandB (
        .A(v_inp[0]),
        .B(clk_i[0]),
        .C(nandA_o),
        .Y(nandB_o)
    );

    //NAND3B_INV
    (* dont_touch = "true" *) gf180mcu_as_sc_mcu7t3v3__inv_2 u_inv_nandB (
        .A(nandB_o),
        .Y(nandB_inv)
    );

    //Route these into 2 NOR3 gates 
    //q_invo = ~(nandA_inv | norA_o | q_o);
    (* dont_touch = "true" *) gf180mcu_as_sc_mcu7t3v3__nor3_2 u_q_inv (
        .A(nandA_inv),
        .B(norA_o),
        .C(q_o[0]),
        .Y(q_invo[0])
    );
    
    //q_o = ~(nandB_inv | norB_o | q_invo);
    (* dont_touch = "true" *) gf180mcu_as_sc_mcu7t3v3__nor3_2 u_q_o (
        .A(nandB_inv),
        .B(norB_o),
        .C(q_invo[0]),
        .Y(q_o[0])
    );

endmodule
