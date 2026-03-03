# test mem2vga module

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


    with open("frame.bmp", "wb") as f:
        # construct bmp header
        # 0-7
        array=bytearray([0x42, 0x4D, 0x36, 0x6C, 0x00, 0x00, 0x00, 0x00])
        f.write(array)
        # 8-15
        array=bytearray([0x00, 0x00, 0x36, 0x00, 0x00, 0x00, 0x28, 0x00])
        f.write(array)
        # 16-23
        array=bytearray([0x00, 0x00, 0x80, 0x02, 0x00, 0x00, 0xE0, 0x01])
        f.write(array)
        # 24-31
        array=bytearray([0x00, 0x00, 0x01, 0x00, 0x18, 0x00, 0x00, 0x00])
        f.write(array)
        # 32-39
        array=bytearray([0x00, 0x00, 0x00, 0x6C, 0x09, 0x00, 0x13, 0x0B])
        f.write(array)
        # 40-47
        array=bytearray([0x00, 0x00, 0x13, 0x0B, 0x00, 0x00, 0x00, 0x00])
        f.write(array)
        # 48-53
        array=bytearray([0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        f.write(array)

        await FallingEdge(dut.clk)
        await FallingEdge(dut.clk)
        await FallingEdge(dut.clk)
        await FallingEdge(dut.clk)
        await FallingEdge(dut.clk)
        await FallingEdge(dut.clk)

        #BMP does pixels bottom to top
        for j in range(479, -1, -1): 
            for i in range (0, 640, 1):
                await FallingEdge(dut.clk)
                if (dut.active_o.value == 0):
                    await RisingEdge(dut.active_o)
                byte = (int(dut.pixel_o.value) & 0x0F0)

                f.write(bytearray([byte, byte, byte]))
