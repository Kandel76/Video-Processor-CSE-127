module cocotb_iverilog_dump();
initial begin
    $dumpfile("sim_build/mem2vga.fst");
    $dumpvars(0, mem2vga);
end
endmodule
