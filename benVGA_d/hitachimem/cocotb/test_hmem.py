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
async def mem_access(dut, DATA=0xe0):
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

    await FallingEdge(dut.reset) # extra wait to test reset
    #initalize values
    dut.wvalid_i.value = 0
    dut.waddr_i.value = 0
    dut.wdata_i.value = 0
    dut.wready_o.value = 0
    dut.raddr_i.value = 0
    dut.data_i.value = 0

    await FallingEdge(dut.reset)
    await FallingEdge(dut.clk)
    #always wait til after reset ------

    dut.waddr_i.value = 77
    dut.raddr_i.value = 77
    for _ in range(6):
        await FallingEdge(dut.clk)

    dut.waddr_i.value = 60000
    dut.raddr_i.value = 60000
    for _ in range(6):
        await FallingEdge(dut.clk)
    


    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
