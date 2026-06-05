* comp_gf180.sp
.subckt comp vinp vinm clk q qb vdd vss

* VNW -> vdd, VPW -> vss

* clkb = inv(clk)
* inv_1: I ZN VDD VNW VPW VSS
Xinvclk clk clkb vdd vdd vss vss gf180mcu_fd_sc_mcu7t5v0__inv_1

* Top-left cross-coupled NOR3 pair
* nor3_1: A1 A2 A3 ZN VDD VNW VPW VSS
XnorT vinm clkb n_mid n_top vdd vdd vss vss gf180mcu_fd_sc_mcu7t5v0__nor3_1
XnorM vinp clkb n_top n_mid vdd vdd vss vss gf180mcu_fd_sc_mcu7t5v0__nor3_1

* Bottom-left cross-coupled NAND3 pair:
* nand3_1: A1 A2 A3 ZN VDD VNW VPW VSS
XnandM vinm clk p_bot_raw p_mid_raw vdd vdd vss vss gf180mcu_fd_sc_mcu7t5v0__nand3_1
XnandB vinp clk p_mid_raw p_bot_raw vdd vdd vss vss gf180mcu_fd_sc_mcu7t5v0__nand3_1

* Invert NAND outputs
XinvM p_mid_raw p_mid vdd vdd vss vss gf180mcu_fd_sc_mcu7t5v0__inv_1
XinvB p_bot_raw p_bot vdd vdd vss vss gf180mcu_fd_sc_mcu7t5v0__inv_1

* Right-side latch with reset using clkb
XnorQB n_top q  clkb qb vdd vdd vss vss gf180mcu_fd_sc_mcu7t5v0__nor3_1
XnorQ  n_mid qb clkb q  vdd vdd vss vss gf180mcu_fd_sc_mcu7t5v0__nor3_1

.ends comp

