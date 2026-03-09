#filler for now, simulate the scanner and memory interface
import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
import random 

@cocotb.test()
async def test_scanner_mem(dut):
    #start the clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    

async def write_to_scanner(dut, address, data):
    dut.scanner_addr.value = address
    

async def read_from_scanner(dut, address):
    dut.scanner_addr.value = address



