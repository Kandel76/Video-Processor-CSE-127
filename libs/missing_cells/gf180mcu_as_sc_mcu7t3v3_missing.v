// Verilog functional models for cells present in the liberty file but
// absent or broken in the distributed gf180mcu_as_sc_mcu7t3v3 verilog model.
// Load this file as a direct source *before* STD_CELL_LIB (or use -l for
// STD_CELL_LIB) so these definitions take precedence.

// dfsrtp_2: the submodule's version assigns to output Q (wire) inside an
// always block. Fix: route through the internal `state` reg and drive Q
// combinatorially, matching the pattern used by dfxtp_2 and dfxtn_2.
module gf180mcu_as_sc_mcu7t3v3__dfsrtp_2(
	input VPW,
	input VNW,
	input VDD,
	input VSS,

	input CLK,
	input D,
	input RN,
	input SN,
	output Q
);

reg state;
wire sr;

assign sr = ~(RN & SN);
assign Q = state;

always @(posedge CLK or posedge sr) begin
	if (sr == 1'b1) begin
		if (RN == 1'b0) begin
			state <= 1'b0;
		end else if (SN == 1'b0) begin
			state <= 1'b1;
		end
	end else begin
		state <= D;
	end
end

endmodule

module gf180mcu_as_sc_mcu7t3v3__ao211_2 (
	input VPW,
	input VNW,
	input VDD,
	input VSS,

	input A,
	input B,
	input C,
	input D,
	output Y
);

assign Y = (A & B) | C | D;

endmodule

module gf180mcu_as_sc_mcu7t3v3__aoi211_2 (
	input VPW,
	input VNW,
	input VDD,
	input VSS,

	input A,
	input B,
	input C,
	input D,
	output Y
);

assign Y = ~((A & B) | C | D);

endmodule

module gf180mcu_as_sc_mcu7t3v3__oai211_2 (
	input VPW,
	input VNW,
	input VDD,
	input VSS,

	input A,
	input B,
	input C,
	input D,
	output Y
);

assign Y = ~((A | B) & C & D);

endmodule
