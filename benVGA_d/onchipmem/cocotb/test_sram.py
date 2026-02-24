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

    
    await FallingEdge(dut.CLK)
    dut.A.value = 0x01;
    dut.D.value = 0xA5;
    dut.GWEN.value = 1;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x01;
    dut.D.value = 0xFF;
    dut.WEN.value = 0xFF;

    await FallingEdge(dut.CLK)
    dut.A.value = 0x01;
    dut.D.value = 0xEE;
    dut.GWEN.value = 0;

    await FallingEdge(dut.CLK)
    print(dut.Q.value)
    await FallingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
