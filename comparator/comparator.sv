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
    (* dont_touch = "true" *) gf180mcu_fd_sc_mcu9t5v0__inv_1 u_inv_clk (
        .I(clk_i[0]),
        .ZN(clk_inv)
    );
    
    //NOR3A
    //assign norA_o = ~(v_inp | clk_inv | norB_o);
    (* dont_touch = "true" *) gf180mcu_fd_sc_mcu9t5v0__nor3_1 u_norA (
        .A1(v_inp[0]),
        .A2(clk_inv),
        .A3(norB_o),
        .ZN(norA_o)
    );
    
    //NOR3B
    //assign norB_o = ~(v_inm | clk_inv | norA_o);
    (* dont_touch = "true" *) gf180mcu_fd_sc_mcu9t5v0__nor3_1 u_norB (
        .A1(v_inm[0]),
        .A2(clk_inv),
        .A3(norA_o),
        .ZN(norB_o)
    );

    //NAND3A
    //assign nandA_o = ~(v_inm & clk_i & nandB_o);
    (* dont_touch = "true" *) gf180mcu_fd_sc_mcu9t5v0__nand3_1 u_nandA (
        .A1(v_inm[0]),
        .A2(clk_i[0]),
        .A3(nandB_o),
        .ZN(nandA_o)
    );

    //NAND3A_INV
    (* dont_touch = "true" *) gf180mcu_fd_sc_mcu9t5v0__inv_1 u_inv_nandA (
        .I(nandA_o),
        .ZN(nandA_inv)
    );

    //NAND3B
    //assign nandB_o = ~(v_inp & clk_i & nandA_o);
    (* dont_touch = "true" *) gf180mcu_fd_sc_mcu9t5v0__nand3_1 u_nandB (
        .A1(v_inp[0]),
        .A2(clk_i[0]),
        .A3(nandA_o),
        .ZN(nandB_o)
    );

    //NAND3B_INV
    (* dont_touch = "true" *) gf180mcu_fd_sc_mcu9t5v0__inv_1 u_inv_nandB (
        .I(nandB_o),
        .ZN(nandB_inv)
    );

    //Route these into 2 NOR3 gates 
    //q_invo = ~(nandA_inv | norA_o | q_o);
    (* dont_touch = "true" *) gf180mcu_fd_sc_mcu9t5v0__nor3_1 u_q_inv (
        .A1(nandA_inv),
        .A2(norA_o),
        .A3(q_o[0]),
        .ZN(q_invo[0])
    );
    
    //q_o = ~(nandB_inv | norB_o | q_invo);
    (* dont_touch = "true" *) gf180mcu_fd_sc_mcu9t5v0__nor3_1 u_q_o (
        .A1(nandB_inv),
        .A2(norB_o),
        .A3(q_invo[0]),
        .ZN(q_o[0])
    );

endmodule
