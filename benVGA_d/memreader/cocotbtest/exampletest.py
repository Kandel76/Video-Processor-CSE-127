# test mem2vga module

import cocotb
from cocotb.triggers import FallingEdge, Timer

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
    cocotb.start_soon(generate_clk_and_reset(dut))

    await FallingEdge(dut.clk)
    dut.d_i.value = 0;
    dut.en_i.value = 0;

    await FallingEdge(dut.reset)
    await FallingEdge(dut.clk)
    cocotb.log.info("Q is %s", dut.q_o.value)
    assert dut.q_o.value == 0

    await FallingEdge(dut.clk)
    dut.d_i.value = 1;
    dut.en_i.value = 1;
    await FallingEdge(dut.clk)
    cocotb.log.info("Q is %s", dut.q_o.value)

@cocotb.test()
async def en_test(dut):

    # cocotb.start_soon(generate_clock(dut))
    cocotb.start_soon(generate_clk_and_reset(dut))

    await FallingEdge(dut.clk)
    dut.d_i.value = 0;
    dut.en_i.value = 0;

    await FallingEdge(dut.reset)
    await FallingEdge(dut.clk)
    cocotb.log.info("Q is %s", dut.q_o.value)

    await FallingEdge(dut.clk)
    dut.d_i.value = 1;
    dut.en_i.value = 1;
    await FallingEdge(dut.clk)
    cocotb.log.info("Q is %s", dut.q_o.value)
