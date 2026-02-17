* comp.sp with sky130 lib
.subckt comp vinp vinm clk q qb vdd vss

* clkb = inv(clk)
* inv_1: A VGND VNB VPB VPWR Y
Xinvclk clk vss vss vdd vdd clkb sky130_fd_sc_hd__inv_1

* Top-left cross-coupled NOR3 pair
* nor3_1: A B C VGND VNB VPB VPWR Y
XnorT vinm clkb n_mid vss vss vdd vdd n_top sky130_fd_sc_hd__nor3_1
XnorM vinp clkb n_top vss vss vdd vdd n_mid sky130_fd_sc_hd__nor3_1

* Bottom-left cross-coupled NAND3 pair
* nand3_1: A B C VGND VNB VPB VPWR Y
XnandM vinm clk p_bot_raw vss vss vdd vdd p_mid_raw sky130_fd_sc_hd__nand3_1
XnandB vinp clk p_mid_raw vss vss vdd vdd p_bot_raw sky130_fd_sc_hd__nand3_1

* Invert NAND outputs
XinvM p_mid_raw vss vss vdd vdd p_mid sky130_fd_sc_hd__inv_1
XinvB p_bot_raw vss vss vdd vdd p_bot sky130_fd_sc_hd__inv_1

* Right-side latch with explicit reset using clkb
* qb = NOR3(n_top, q,  clkb)
* q  = NOR3(n_mid, qb, clkb)
XnorQB n_top q  clkb vss vss vdd vdd qb sky130_fd_sc_hd__nor3_1
XnorQ  n_mid qb clkb vss vss vdd vdd q  sky130_fd_sc_hd__nor3_1

.ends comp
