# test mem2vga module

import cocotb
from cocotb.triggers import FallingEdge, Timer


async def generate_clock(dut):
    # generate 25MHz clk

    for _ in range(10):
        dut.clk.value = 0
        await Timer(20, unit="ns")
        dut.clk.value = 1
        await Timer(20, unit="ns")

@cocotb.test()
async def my_test(dut):

    cocotb.start_soon(generate_clock(dut))  # run the clock "in the background"

    await FallingEdge(dut.clk)  # wait for falling edge/"negedge"
    cocotb.log.info("B is %s", dut.B.value)
    await FallingEdge(dut.clk)  # wait for falling edge/"negedge"
    cocotb.log.info("B is %s", dut.B.value)
    await FallingEdge(dut.clk)  # wait for falling edge/"negedge"
    cocotb.log.info("B is %s", dut.B.value)
    await Timer(10, unit="ns")
    cocotb.log.info("B is now %s", dut.B.value)
    await FallingEdge(dut.clk)  # wait for falling edge/"negedge"
    cocotb.log.info("B is %s", dut.B.value)
    await FallingEdge(dut.clk)  # wait for falling edge/"negedge"
    cocotb.log.info("B is %s", dut.B.value)
