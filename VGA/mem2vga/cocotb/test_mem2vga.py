# test mem2vga module

import cocotb
from cocotb.triggers import FallingEdge, Timer, RisingEdge, First
import logging


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

# memory helpers ====================================================
async def mem_access(dut, DATA=0xe0): # going to depreciate this
    dut.valid_i.value=0

    #simulate access time
    await Timer(85, unit="ns")

    #give data
    dut.data_i.value = DATA
    dut.valid_i.value = 1

async def external_mem1(dut):    # simulated external memory 1
    #dictionary to simulate specified addresses
    # look for low nCS1
    # TODO note: ***THIS DOES NOT PRECISELY CHECK THE TIMINGS***
    sim_memory = dict()

    # pre-set what is in the memory
    sim_memory[500] = 0x37
    sim_memory[501] = 0xBF


    while (1):
        action = await First(FallingEdge(dut.nWE_o), FallingEdge(dut.nOE_o)) # wait for a read or write to start
        await Timer(1, unit="ps") #looking for the values which are held for 3 cycles
        # there seems to be a race condition somewhere, but the values should be held for 3 cycles
        # so idk man Im just gonna leave this wait here

        if (dut.nCS1_o.value == 0): #if chip one is selected

            if (dut.nCS2_o.value == 0):
                print(" ! ERROR: MEM1: Both chip select values are high")

            if (action == FallingEdge(dut.nWE_o)): #WRITE
                await Timer(85, unit="ns")
                sim_memory[int(dut.addr_o.value)] = dut.data_o.value

            else: # READ
                dut.data_i.value = 0xbd #bad data value. If you see this in output, there's an error in timing
                if (int(dut.addr_o.value) in sim_memory.keys()):
                    await Timer(85, unit="ns")
                    dut.data_i.value = sim_memory[int(dut.addr_o.value)]
                else:
                    # print(" ! ERROR: MEM1: Attempted to access nonexistent memory address", int(dut.addr_o.value))
                    dut.data_i.value = 0x00

async def external_mem2(dut):    # simulated external memory 2
    #dictionary to simulate specified addresses
    # look for low nCS2
    # TODO note: ***THIS DOES NOT PRECISELY CHECK THE TIMINGS***
    sim_memory2 = dict()

    while (1):
        action = await First(FallingEdge(dut.nWE_o), FallingEdge(dut.nOE_o)) # wait for a read or write to start
        await Timer(1, unit="ps") #looking for the values which are held for 3 cycles
        # there seems to be a race condition somewhere, but the values should be held for 3 cycles
        # so idk man Im just gonna leave this wait here

        if (dut.nCS2_o.value == 0): #if chip two is selected

            if (dut.nCS1_o.value == 0):
                print(" ! ERROR: MEM2: Both chip select values are high")

            if (action == FallingEdge(dut.nWE_o)): #WRITE
                await Timer(85, unit="ns")
                sim_memory2[int(dut.addr_o.value)] = dut.data_o.value
            elif (action == FallingEdge(dut.nOE_o)): # READ
                dut.data_i.value = 0xbd #bad data value. If you see this in output, there's an error in timing
                if (int(dut.addr_o.value) in sim_memory2.keys()):
                    await Timer(85, unit="ns")
                    dut.data_i.value = sim_memory2[int(dut.addr_o.value)]
                else:
                    # print(" ! ERROR: MEM2: Attempted to access nonexistent memory address", int(dut.addr_o.value))
                    dut.data_i.value = 0x00

# tests ===================================================
@cocotb.test()
async def reset_test(dut):

    # cocotb.start_soon(generate_clock(dut))
    cocotb.start_soon(generate_clk_and_reset(dut, 500000))
    cocotb.start_soon(external_mem1(dut))
    cocotb.start_soon(external_mem2(dut))

    # set values to zero
    dut.waddr_i.value = 0
    dut.wdata_i.value = 0
    dut.data_i.value = 0xee

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

        #BMP does pixels bottom to top, left to right

        for j in range(479, -1, -1): 
            for i in range (639, -1, -1):
                # if (dut.active_o.value == 0):
                #     await RisingEdge(dut.active_o)
                await FallingEdge(dut.clk)
                while (dut.active_o.value == 0):
                    await FallingEdge(dut.clk)
                byte = (int(dut.pixel_o.value) & 0x0F0)

                f.write(bytearray([byte, byte, byte]))
