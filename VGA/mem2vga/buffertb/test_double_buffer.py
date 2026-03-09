# test double buffer module

import cocotb
from cocotb.triggers import FallingEdge, Timer, RisingEdge

# helpers =================================================
async def generate_clock(dut, NUMCYCLES=200):
    # generate 25MHz clk

    for _ in range(NUMCYCLES):
        dut.clk.value = 0
        await Timer(20, unit="ns")
        dut.clk.value = 1
        await Timer(20, unit="ns")

async def generate_clk_and_reset(dut, NUMCYCLES=200, BEFORE=2, DURING=3):
    # generate a reset signal
    # parameters are for total clock cycles, number of cycles before and during reset
    
    cocotb.start_soon(generate_clock(dut, NUMCYCLES))

    dut.reset.value = 0
    for _ in range(BEFORE):
        await FallingEdge(dut.clk)
    dut.reset.value = 1
    for _ in range(DURING):
        await FallingEdge(dut.clk)
    dut.reset.value = 0


# tests ===================================================
@cocotb.test()
async def reset_test(dut):

    # cocotb.start_soon(generate_clock(dut))
    cocotb.start_soon(generate_clk_and_reset(dut, 500000))

    await FallingEdge(dut.reset)

    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
