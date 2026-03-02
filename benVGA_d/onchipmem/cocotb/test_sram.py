# Testbench for the memory reader
# Uses helper functions to simulate the external memory
import cocotb
from cocotb.triggers import FallingEdge, Timer, RisingEdge

# helpers =================================================
async def generate_clock(dut, NUMCYCLES=200):
    # generate 25MHz clk

    for _ in range(NUMCYCLES):
        dut.CLK.value = 0
        await Timer(20, unit="ns")
        dut.CLK.value = 1
        await Timer(20, unit="ns")

# tests ===================================================
@cocotb.test()
async def reset_test(dut):
    # initalize values
    dut.GWEN.value = 0;
    dut.WEN.value = 0x00;
    dut.A.value = 0x00;
    dut.D.value = 0x00;

    cocotb.start_soon(generate_clock(dut))

    dut.CEN.value = 1;

    await Timer(19, unit="ns")
    await Timer(950, unit="ps")
    dut.CEN.value = 0;
    await Timer(400, unit="ps")
    dut.CEN.value = 1;

    await FallingEdge(dut.CLK)
    await Timer(19, unit="ns")
    await Timer(950, unit="ps")
    dut.CEN.value = 0;

    # generate CEN
    await FallingEdge(dut.CLK)

    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    #always wait til after reset ------

    #       GW  W   A   D
    #READ   1   X   A   X
    #WRITE  0   1   A   D
    
    #write
    await FallingEdge(dut.CLK)
    dut.A.value = 0x01;
    dut.D.value = 0x11;
    dut.WEN.value = 0x00;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x02;
    dut.D.value = 0x22;
    dut.WEN.value = 0x00;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x04;
    dut.D.value = 0x33;
    dut.WEN.value = 0x00;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x08;
    dut.D.value = 0x44;
    dut.WEN.value = 0x00;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x10;
    dut.D.value = 0x55;
    dut.WEN.value = 0x00;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x20;
    dut.D.value = 0x66;
    dut.WEN.value = 0x00;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x40;
    dut.D.value = 0x77;
    dut.WEN.value = 0x00;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x80;
    dut.D.value = 0x88;
    dut.WEN.value = 0x00;

    #read
    await FallingEdge(dut.CLK)
    dut.A.value = 0x80;
    dut.GWEN.value = 1;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x40;
    dut.GWEN.value = 1;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x20;
    dut.GWEN.value = 1;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x10;
    dut.GWEN.value = 1;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x08;
    dut.GWEN.value = 1;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x04;
    dut.GWEN.value = 1;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x02;
    dut.GWEN.value = 1;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x01;
    dut.GWEN.value = 1;


    #let waveform show final values
    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
