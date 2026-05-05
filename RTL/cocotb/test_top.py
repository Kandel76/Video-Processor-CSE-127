import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

CLK_PERIOD_NS = 10

async def reset_dut(dut):
  #initialize inputs
  dut.rst_n.value = 0
  dut.frame_start.value = 0
  dut.cmp_q.value = 0
  dut.wready_i.value = 1  #always ready to accept memory writes

  #hold reset
  await ClockCycles(dut.clk, 5)

  dut.rst_n.value = 1
  await ClockCycles(dut.clk, 2)


@cocotb.test()
async def top_reaches_frame_done(dut):
  cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())

  await reset_dut(dut)

  #start one frame
  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  # for now, we set cmp_q = 0 (all pixels = 0)
  # and checking if the system runs and reaches frame_done
  # will check other images later
  for cycle in range(1000):
    dut.cmp_q.value = 0

    await RisingEdge(dut.clk)

    #check if fram completes
    if int(dut.frame_done.value) == 1:
        dut._log.info(f"frame_done reached at cycle {cycle}")
        return

  # if we never reached frame_done, test fails
  assert dut.frame_done.value == 1, "did not reach frame_done"
