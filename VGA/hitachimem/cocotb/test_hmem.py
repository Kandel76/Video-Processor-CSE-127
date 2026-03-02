# Testbench for the memory reader
# Uses helper functions to simulate the external memory
import cocotb
from cocotb.triggers import FallingEdge, Timer, RisingEdge, First

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

    # writing
    while (1):
        action = await First(FallingEdge(dut.nWE), FallingEdge(dut.nOE)) # wait for a read or write to start
        if (dut.nCS1_o.value == 0): #if chip one is selected
            if (action == FallingEdge(dut.nWE)):
                await Timer(85, unit="ns")
                sim_memory[str(dut.addr_o.value)] = dut.data_o.value
            else:
                dut.data_i.value = 0xbd
                if (str(dut.addr_o.value) in sim_memory):
                    await Timer(85, unit="ns")
                    dut.data_i.value = sim_memory[str(dut.addr_o.value)]


# tests =============================================================
@cocotb.test()
async def reset_test(dut):

    # cocotb.start_soon(generate_clock(dut))
    cocotb.start_soon(generate_clk_and_reset(dut))

    cocotb.start_soon(external_mem1(dut))

    await FallingEdge(dut.reset) # extra wait to test reset
    #initalize values
    dut.waddr_i.value = 0
    dut.wdata_i.value = 0
    dut.raddr_i.value = 0
    dut.data_i.value = 0

    await FallingEdge(dut.reset)
    await FallingEdge(dut.clk)
    #always wait til after reset ------

    dut.waddr_i.value = 77
    dut.wdata_i.value = 0x69
    for _ in range(6):
        await FallingEdge(dut.clk)

    dut.waddr_i.value = 31000
    dut.raddr_i.value = 77
    for _ in range(6):
        await FallingEdge(dut.clk)

    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)

@cocotb.test()
async def write_read_test(dut):

    # cocotb.start_soon(generate_clock(dut))
    cocotb.start_soon(generate_clk_and_reset(dut))

    cocotb.start_soon(external_mem1(dut))

    await FallingEdge(dut.reset) # extra wait to test reset
    #initalize values
    dut.waddr_i.value = 0
    dut.wdata_i.value = 0
    dut.raddr_i.value = 0
    dut.data_i.value = 0

    await FallingEdge(dut.reset)
    await FallingEdge(dut.clk)
    #always wait til after reset ------

    dut.waddr_i.value = 0x77
    dut.wdata_i.value = 0x69
    for _ in range(6):
        await FallingEdge(dut.clk)
    
    dut.waddr_i.value = 31000
    dut.raddr_i.value = 77
    for _ in range(6):
        await FallingEdge(dut.clk)

    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
