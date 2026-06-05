# Testbench for the memory reader
# Uses helper functions to simulate the external memory
import cocotb
from cocotb.triggers import FallingEdge, Timer, RisingEdge, First
import logging

# helpers ===========================================================
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
sim_memory = dict()
sim_memory2 = dict()

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

    while (1):
        action = await First(FallingEdge(dut.nWE), FallingEdge(dut.nOE)) # wait for a read or write to start
        await Timer(1, unit="ps") #looking for the values which are held for 3 cycles
        # there seems to be a race condition somewhere, but the values should be held for 3 cycles
        # This picosecond wait is just to make sure that we are acting after the detected edge rather
        # than before. It could be that the simulator internally updates the nWE and nOE values
        # before the nCS1_o values, even though they both change on the same clock edge.

        if (dut.nCS1_o.value == 0): #if chip one is selected

            if (dut.nCS2_o.value == 0):
                print(" ! ERROR: MEM1: Both chip select values are high")

            if (action == FallingEdge(dut.nWE)): #WRITE
                await Timer(85, unit="ns")
                sim_memory[int(dut.addr_o.value)] = dut.data_o.value

            else: # READ
                dut.data_i.value = 0xbd #bad data value. If you see this in output, there's an error in timing
                if (int(dut.addr_o.value) in sim_memory.keys()):
                    await Timer(85, unit="ns")
                    dut.data_i.value = sim_memory[int(dut.addr_o.value)]
                else:
                    # print(" ! ERROR: MEM1: Attempted to access nonexistent memory address", int(dut.addr_o.value))
                    dut.data_i.value = 0xEE

async def external_mem2(dut):    # simulated external memory 2
    #dictionary to simulate specified addresses
    # look for low nCS2
    # TODO note: ***THIS DOES NOT PRECISELY CHECK THE TIMINGS***
    # sim_memory2 = dict()

    while (1):
        action = await First(FallingEdge(dut.nWE), FallingEdge(dut.nOE)) # wait for a read or write to start
        await Timer(1, unit="ps") #looking for the values which are held for 3 cycles
        # there seems to be a race condition somewhere, but the values should be held for 3 cycles

        if (dut.nCS2_o.value == 0): #if chip two is selected

            if (dut.nCS1_o.value == 0):
                print(" ! ERROR: MEM2: Both chip select values are high")

            if (action == FallingEdge(dut.nWE)): #WRITE
                await Timer(85, unit="ns")
                sim_memory2[int(dut.addr_o.value)] = dut.data_o.value

            elif (action == FallingEdge(dut.nOE)): # READ
                dut.data_i.value = 0xbd #bad data value. If you see this (dec 189) in output, there's an error
                if (int(dut.addr_o.value) in sim_memory2.keys()):
                    await Timer(85, unit="ns")
                    dut.data_i.value = sim_memory2[int(dut.addr_o.value)]
                else:
                    print(" ! ERROR: MEM2: Attempted to access nonexistent memory address", int(dut.addr_o.value))
                    dut.data_i.value = 0x24



# tests =============================================================
@cocotb.test()
async def small_test(dut):
    errored = False
    # cocotb setup stuff
    logger = logging.getLogger("memtest")

    # cocotb.start_soon(generate_clock(dut))
    cocotb.start_soon(generate_clk_and_reset(dut, 80000))

    cocotb.start_soon(external_mem1(dut))
    cocotb.start_soon(external_mem2(dut))

    #initalize values
    dut.waddr_i.value = 0
    dut.wdata_i.value = 0
    dut.raddr_i.value = 0
    dut.data_i.value = 0
    dut.wvalid_i.value = 0

    await FallingEdge(dut.reset)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    #always wait til after reset ------

    #TEST THAT WRITTEN DATA CAN BE READ
    for i in range(32):
        dut.waddr_i.value = int(i + 10)
        dut.wdata_i.value = i
        dut.wvalid_i.value = 1
        for _ in range(6):
            await FallingEdge(dut.clk)

    for i in range(32):
        dut.raddr_i.value = int(i + 10)
        await RisingEdge(dut.rvalid_o)
        await RisingEdge(dut.clk)
        if (dut.rdata_o.value != i & i != 0):
            logger.error(f"expected value: {i}, got value: {int(dut.rdata_o.value)} from address {dut.raddr_i.value}")
            errored = True

    assert (errored == False)

@cocotb.test()
async def big_address_test(dut):
    errored = False
    # cocotb setup stuff
    logger = logging.getLogger("memtest")

    # cocotb.start_soon(generate_clock(dut))
    cocotb.start_soon(generate_clk_and_reset(dut, 80000))

    cocotb.start_soon(external_mem1(dut))
    cocotb.start_soon(external_mem2(dut))

    #initalize values
    dut.waddr_i.value = 0
    dut.wdata_i.value = 0
    dut.raddr_i.value = 0
    dut.data_i.value = 0
    dut.wvalid_i.value = 0

    await FallingEdge(dut.reset)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    #always wait til after reset ------

    await FallingEdge(dut.clk)
    dut.reset.value = 0
    for i in range(6):
        await FallingEdge(dut.clk)

    for i in range(1, 32):
        dut.waddr_i.value = int(i + 0x7000)
        dut.wdata_i.value = i
        dut.wvalid_i.value = 1
        for _ in range(6):
            await FallingEdge(dut.clk)
            # dut.wvalid_i.value = 0

    for i in range(1, 32):
        dut.raddr_i.value = int(i + 0x7000)
        await RisingEdge(dut.rvalid_o)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        if (dut.rdata_o.value != i & i != 1):
            logger.error(f"expected value: {i}, got value: {int(dut.rdata_o.value)} from address {dut.raddr_i.value}")
            errored = True

    assert (errored == False)

@cocotb.test()
async def bigger_address_test(dut):
    errored = False
    # cocotb setup stuff
    logger = logging.getLogger("memtest")

    # cocotb.start_soon(generate_clock(dut))
    cocotb.start_soon(generate_clk_and_reset(dut, 80000))

    cocotb.start_soon(external_mem1(dut))
    cocotb.start_soon(external_mem2(dut))

    #initalize values
    dut.waddr_i.value = 0
    dut.wdata_i.value = 0
    dut.raddr_i.value = 0
    dut.data_i.value = 0
    dut.wvalid_i.value = 0

    await FallingEdge(dut.reset)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    #always wait til after reset ------

    await FallingEdge(dut.clk)
    dut.reset.value = 0
    for i in range(6):
        await FallingEdge(dut.clk)

    # testing that memory 2 can be read/written
    await FallingEdge(dut.clk)
    dut.reset.value = 0
    for i in range(6):
        await FallingEdge(dut.clk)

    for i in range(1, 32):
        dut.waddr_i.value = int(i + 0x8000)
        dut.wdata_i.value = i
        dut.wvalid_i.value = 1
        for _ in range(6):
            await FallingEdge(dut.clk)

    for i in range(1, 32):
        dut.raddr_i.value = int(i + 0x8000)
        await RisingEdge(dut.rvalid_o)
        await RisingEdge(dut.clk)
        if (dut.rdata_o.value != i & i != 1):
            logger.error(f"expected value: {i}, got value: {int(dut.rdata_o.value)} from address {dut.raddr_i.value}")
            errored = True

    assert (errored == False)