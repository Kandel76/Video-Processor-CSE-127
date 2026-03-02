module cocotb_iverilog_dump();
initial begin
    $dumpfile("sim_build/hmem_access.fst");
    $dumpvars(0, hmem_access);
end
endmodule
