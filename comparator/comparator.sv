module comparator (
    input [0:0] clk_i,
    input [0:0] v_inp,
    input [0:0] v_inm,
    output [0:0] q_o,
    output [0:0] q_invo
);
//inverted signal to drive comparator NOR3's
logic [0:0] clk_inv;
assign clk_inv = ~clk_i;

//NOR3A
logic [0:0] norA_o; 
assign norA_o = (~v_inp) & (~clk_inv) & (~norB_o);

//NOR3B
logic [0:0] norB_o; 
assign norB_o = (~v_inm) & (~clk_inv) & (~norA_o);

//NAND3A
logic [0:0] nandA_o; 
assign nandA_o = ~(v_inm & clk_i & nandB_o);
//Invert NAND3A
logic [0:0] nandA_inv; 
assign nandA_inv = ~nandA_o; 

//NAND3B
logic [0:0] nandB_o; 
assign nandB_o = ~(v_inp & clk_i & nandA_o);
//Invert NAND3B
logic [0:0] nandB_inv; 
assign nandB_inv = ~nandB_o; 

//Route these into 2 NOR3 gates 
//q_invo
assign q_invo = ~(nanaA_inv) & ~(norA_o) & ~(q_o);
//q_o
assign q_o = ~(nandB_inv) & ~(norB_o) & ~(q_invo);

endmodule
