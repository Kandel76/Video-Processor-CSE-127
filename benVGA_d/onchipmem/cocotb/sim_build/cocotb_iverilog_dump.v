module cocotb_iverilog_dump();
initial begin
    $dumpfile("sim_build/gf180mcu_ocd_ip_sram__sram256x8m8wm1.fst");
    $dumpvars(0, gf180mcu_ocd_ip_sram__sram256x8m8wm1);
end
endmodule
