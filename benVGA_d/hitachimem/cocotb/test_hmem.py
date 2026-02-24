# Testbench for the memory reader
# Uses helper functions to simulate the external memory
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


# memory helpers ==========================================
async def ext_mem_access(dut, DATA=0xe0):
    dut.valid_i.value=0

    #simulate access time
    await Timer(85, unit="ns")

    #give data
    dut.data_i.value = DATA
    dut.valid_i.value = 1

# tests ===================================================
@cocotb.test()
async def reset_test(dut):

    # cocotb.start_soon(generate_clock(dut))
    cocotb.start_soon(generate_clk_and_reset(dut))

    await FallingEdge(dut.clk)
    #initalize values
    dut.data_i.value = 0x00
    dut.valid_i.value = 0
    dut.ready_i.value = 0

    await FallingEdge(dut.reset)
    await FallingEdge(dut.clk)
    #always wait til after reset ------

    
    dut.ready_i.value = 1           #interface asks for data
    await RisingEdge(dut.ready_o)   #wait for module to ask, then run mem_access
    await mem_access(dut, DATA=0xff)

    print(dut.valid_o.value)
    print(dut.data_o.value)
    await RisingEdge(dut.valid_o)   #wait for module to say ready
    print("----")
    print(dut.valid_o.value)
    print(dut.data_o.value)


    #extra clock edges at end to see final values
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
