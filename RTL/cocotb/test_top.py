import cocotb
import numpy as np

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


CLK_PERIOD_NS = 10

#load test image from test_images folder
def load_img(filename):
  return np.load(f"../../test_images/{filename}")

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

#generate comparator outputs from image pixels and threshold
def get_cmp_q(row_pixels, threshold):
  cmp_value = 0

  for col in range(len(row_pixels)):
    pixel = int(row_pixels[col])

    #comparator output is 1 if pixel > threshold
    if pixel > threshold:
      cmp_value |= 1 << (col+1)

  return cmp_value


@cocotb.test()
async def top_reaches_frame_done(dut):
  cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())

  await reset_dut(dut)

  #load gradient test image first
  #will add the rest of the test images after testing
  image = load_img("img2_gradient.npy")

  #start one frame
  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  # driving cmp_q like comparator: cmp_q bit = 1 when pixel value > duty_cycle
  # checking if the system runs and reaches frame_done
  for cycle in range(1000):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    # drive comparator outputs for current row
    if row < image.shape[0]:
      row_pixels = image[row]
      dut.cmp_q.value = get_cmp_q(row_pixels, threshold)
    else:
      dut.cmp_q.value = 0

    await RisingEdge(dut.clk)

    #check if frame completes
    if int(dut.frame_done.value) == 1:
        dut._log.info(f"frame_done reached at cycle {cycle}")
        return

  # if we never reached frame_done, test fails
  assert dut.frame_done.value == 1, "did not reach frame_done"
