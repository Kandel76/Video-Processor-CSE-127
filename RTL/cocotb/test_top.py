import cocotb
import numpy as np
import os

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


CLK_PERIOD_NS = 40
ROWS         = 4
COLS         = 4
BYTES_PER_ROW = COLS // 2

image1 = "img3_center_square.npy"
image2 = "img_all_fifteens.npy"


#load test image from test_images folder
def load_img(filename):
  return np.load(f"../test_images/{filename}")

async def reset_dut(dut):
  #initialize inputs
  dut.rst_n.value = 0
  dut.frame_start.value = 0
  dut.cmp_o.value = 0
  dut.wready_i.value = 1  #always ready to accept memory writes

  #hold reset
  await ClockCycles(dut.clk, 5)

  dut.rst_n.value = 1
  await ClockCycles(dut.clk, 2)


##---------------------Memory capture and expected value generation-----------------------##
# Each byte: even pixel -> [7:4], odd pixel -> [3:0]
def build_expected_memory(image, rows=ROWS, cols=COLS):
    img       = image[:rows, :cols] #crop to expected size
    even_cols = img[:, 0::2]   # all even columns
    odd_cols  = img[:, 1::2]   # all odd columns
    #left shift even pixels and pack with odd pixels
    packed = ((even_cols << 4) | odd_cols).astype(np.uint8)  # pack two 4-bit pixels into one byte
    return packed.flatten()  # flatten to 1D array


async def capture_dut_writes(dut, dut_memory, backpressure=False):
    # Each time a row is ready, scanner_to_mem drains BYTES_PER_ROW bytes to memory.
    # We wait for row_data_valid, let the registers latch, then record each write.
    
    # When backpressure=True, each byte is only counted once wready_i=1, so stall
    # cycles are skipped correctly.
    while True:
        await RisingEdge(dut.clk)

        if int(dut.row_data_valid.value) == 1:  # capture when row data valid signal is high
            await RisingEdge(dut.clk)

            for i in range(BYTES_PER_ROW):
                await RisingEdge(dut.clk)
                if backpressure:
                    while int(dut.wready_i.value) == 0: #wait for wready_i to be 1 (release backpressure)
                        await RisingEdge(dut.clk)
                #get the addr and data and set into dut_mem
                addr = int(dut.waddr_o.value)
                data = int(dut.wdata_o.value)
                if 0 <= addr < len(dut_memory):
                    dut_memory[addr] = data
##--------------------------------------------------------------------------------------##


#generate comparator outputs from image pixels and threshold
#returns a binary string
def get_cmp_o(row_pixels, threshold, cmp_width, dark_ref=0):
  bits = ["0"] * cmp_width

  # bit 0 is the dark reference column
  if dark_ref > threshold:
    bits[0] = "1"

  for col in range(len(row_pixels)):
    pixel = int(row_pixels[col])

    #comparator output is 1 if pixel > threshold
    if pixel > threshold:
      bits[col + 1] = "1"
  #reversed bc cocotb expects MSB on the left side
  return "".join(reversed(bits))


# expected memory accounting for dark reference subtraction:
# each pixel output = max(pixel - dark_ref, 0)
def build_expected_memory_dark_ref(image, dark_ref, rows=ROWS, cols=COLS):
  img      = image[:rows, :cols]
  adjusted = np.clip(img.astype(int) - dark_ref, 0, 15).astype(np.uint8)
  even_cols = adjusted[:, 0::2]
  odd_cols  = adjusted[:, 1::2]
  packed = ((even_cols << 4) | odd_cols).astype(np.uint8)
  return packed.flatten()




@cocotb.test()
async def frame_done_test(dut):

  Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start()

  await reset_dut(dut)

  #load gradient test image first
  #will add the rest of the test images after testing

  image = load_img(image1)
  expected_mem = build_expected_memory(image)
  actual_mem = np.zeros_like(expected_mem, dtype=np.uint8) #create array size of expected with all zeros
  cocotb.start_soon(capture_dut_writes(dut, actual_mem))

  #pulse frame start to begin processing
  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  # driving cmp_q like comparator: cmp_q bit = 1 when pixel value > duty_cycle
  
  # checking if the system runs and reaches frame_done
  for cycle in range(2_000_000):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    # drive comparator outputs for current row
    cols = len(dut.cmp_o) - 1
    if row < image.shape[0]:
      row_pixels = image[row, :cols]
      dut.cmp_o.value = get_cmp_o(row_pixels, threshold, len(dut.cmp_o))
    else:
      dut.cmp_o.value = 0

    await RisingEdge(dut.clk)
    if(cycle % 100 == 0): #print every 100 cycles for visibility
      print(f"Cycle {cycle}: row={row}, threshold={threshold}, cmp_o={dut.cmp_o.value}, frame_done={dut.frame_done.value}")

    #check if frame completes
    if ((dut.frame_done.value) == 1) & (np.array_equal(actual_mem, expected_mem) ):
        dut._log.info(f"frame_done reached at cycle {cycle}; Memory contents match expected values")
        return

  assert dut.frame_done.value == 1, "did not reach frame_done"
  assert np.array_equal(actual_mem, expected_mem), \
    f"Memory mismatch\nexpected: {expected_mem}\nactual:   {actual_mem}"



STALL_CYCLES = 20

#waits for row data valid -- stalls -- then sets wready_i to 1
async def apply_backpressure(dut, stall_cycles=STALL_CYCLES):
  while int(dut.row_data_valid.value) != 1:
    await RisingEdge(dut.clk)
  await ClockCycles(dut.clk, stall_cycles)
  dut.wready_i.value = 1
  dut._log.info(f"Backpressure released after {stall_cycles} stall cycles")


@cocotb.test()
async def back_pressure_test(dut):
  Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start()
  await reset_dut(dut)

  image = load_img(image1)
  expected_mem = build_expected_memory(image)
  actual_mem = np.zeros_like(expected_mem, dtype=np.uint8)
  cocotb.start_soon(capture_dut_writes(dut, actual_mem, backpressure=True))

  dut.wready_i.value = 0  # assert backpressure from the start
  cocotb.start_soon(apply_backpressure(dut))

  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  for cycle in range(2_000_000):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    cols = len(dut.cmp_o) - 1
    if row < image.shape[0]:
      #drive comparator outputs for current row
      row_pixels = image[row, :cols]
      dut.cmp_o.value = get_cmp_o(row_pixels, threshold, len(dut.cmp_o))
    else:
      dut.cmp_o.value = 0

    await RisingEdge(dut.clk)

    if int(dut.frame_done.value) == 1 and np.array_equal(actual_mem, expected_mem):
      dut._log.info(f"frame_done reached at cycle {cycle}; Memory contents match expected values")
      return

  assert int(dut.frame_done.value) == 1, "did not reach frame_done after releasing backpressure"
  assert np.array_equal(actual_mem, expected_mem), \
    f"Memory mismatch\nexpected: {expected_mem}\nactual:   {actual_mem}"


@cocotb.test()
async def multiple_frame_test(dut):
  cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
  await reset_dut(dut)

  # first frame
  image = load_img(image1)
  expected_mem = build_expected_memory(image)
  actual_mem = np.zeros_like(expected_mem, dtype=np.uint8)
  cocotb.start_soon(capture_dut_writes(dut, actual_mem))

  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  for cycle in range(2_000_000):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    cols = len(dut.cmp_o) - 1
    if row < image.shape[0]:
      row_pixels = image[row, :cols]
      dut.cmp_o.value = get_cmp_o(row_pixels, threshold, len(dut.cmp_o))
    else:
      dut.cmp_o.value = 0

    await RisingEdge(dut.clk)

    if int(dut.frame_done.value) == 1 and np.array_equal(actual_mem, expected_mem):
      dut._log.info(f"Frame 1: frame_done at cycle {cycle}; Memory contents match")
      break
  else:
    assert False, "Frame 1: did not reach frame_done"

  # second frame
  img2 = load_img(image2)
  expected_mem2 = build_expected_memory(img2)
  actual_mem2 = np.zeros_like(expected_mem2, dtype=np.uint8)
  cocotb.start_soon(capture_dut_writes(dut, actual_mem2))

  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  for cycle in range(2_000_000):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    cols = len(dut.cmp_o) - 1
    if row < img2.shape[0]:
      row_pixels = img2[row, :cols]
      dut.cmp_o.value = get_cmp_o(row_pixels, threshold, len(dut.cmp_o))
    else:
      dut.cmp_o.value = 0

    await RisingEdge(dut.clk)

    if int(dut.frame_done.value) == 1 and np.array_equal(actual_mem2, expected_mem2):
      dut._log.info(f"Frame 2: frame_done at cycle {cycle}; Memory contents match")
      return

  assert int(dut.frame_done.value) == 1, "Frame 2: did not reach frame_done"
  assert np.array_equal(actual_mem2, expected_mem2), \
    f"Frame 2: Memory mismatch\nexpected: {expected_mem2}\nactual:   {actual_mem2}"
  

#frame start before frame done test (expected: should ignore frame start in an active frame and not crash)
#intent: frame start will be always active in top mod, makes sure this doesnt interfere with processing and cause any issues
@cocotb.test()
async def frame_start_during_active_frame_test(dut):

  Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start()

  await reset_dut(dut)

  #load gradient test image first
  #will add the rest of the test images after testing

  image = load_img(image1)
  expected_mem = build_expected_memory(image)
  actual_mem = np.zeros_like(expected_mem, dtype=np.uint8) #create array size of expected with all zeros
  cocotb.start_soon(capture_dut_writes(dut, actual_mem))

  #pulse frame start to begin processing
  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  # driving cmp_q like comparator: cmp_q bit = 1 when pixel value > duty_cycle
  
  # checking if the system runs and reaches frame_done
  for cycle in range(2_000_000):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    #pulse frame start every 200 cycles to test if it causes any issues)
    if cycle % 200 == 0:
      dut.frame_start.value = 1
    else:
      dut.frame_start.value = 0

    # drive comparator outputs for current row
    cols = len(dut.cmp_o) - 1
    if row < image.shape[0]:
      row_pixels = image[row, :cols]
      dut.cmp_o.value = get_cmp_o(row_pixels, threshold, len(dut.cmp_o))
    else:
      dut.cmp_o.value = 0

    await RisingEdge(dut.clk)

    #check if frame completes
    if ((dut.frame_done.value) == 1) & (np.array_equal(actual_mem, expected_mem) ):
        dut._log.info(f"frame_done reached at cycle {cycle}; Memory contents match expected values")
        return

  assert dut.frame_done.value == 1, "did not reach frame_done"
  assert np.array_equal(actual_mem, expected_mem), \
    f"Memory mismatch\nexpected: {expected_mem}\nactual:   {actual_mem}"


@cocotb.test()
async def no_frame_start_test(dut):
  Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start()
  await reset_dut(dut)

  #drive comparator outputs for a few cycles without ever pulsing frame start
  for cycle in range(1000):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    cols = len(dut.cmp_o) - 1
    if row < ROWS:
      row_pixels = np.zeros(cols, dtype=np.uint8)  # all pixels below threshold
      dut.cmp_o.value = get_cmp_o(row_pixels, threshold, len(dut.cmp_o))
    else:
      dut.cmp_o.value = 0

    await RisingEdge(dut.clk)

  assert int(dut.frame_done.value) == 0, "frame_done should not be high without frame_start"



#verify asserting reset mid frame does not prevent a new clean frame
#resets mid first frame and then starts a new frame
@cocotb.test()
async def mid_frame_reset_test(dut):
  cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
  await reset_dut(dut)

  image = load_img(image1)
  expected_mem = build_expected_memory(image)

  cocotb.start_soon(capture_dut_writes(dut, np.zeros_like(expected_mem, dtype=np.uint8)))

  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  # drive first frame for 500 cycles then assert reset
  for cycle in range(500):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    cols = len(dut.cmp_o) - 1
    if row < image.shape[0]:
      row_pixels = image[row, :cols]
      dut.cmp_o.value = get_cmp_o(row_pixels, threshold, len(dut.cmp_o))
    else:
      dut.cmp_o.value = 0

    await RisingEdge(dut.clk)

  dut._log.info("Asserting reset mid-frame")
  dut.rst_n.value = 0
  await ClockCycles(dut.clk, 5)
  dut.rst_n.value = 1

  # fresh capture buffer and new frame start after reset
  actual_mem2 = np.zeros_like(expected_mem, dtype=np.uint8)
  cocotb.start_soon(capture_dut_writes(dut, actual_mem2))

  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  for cycle in range(2_000_000):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    cols = len(dut.cmp_o) - 1
    if row < image.shape[0]:
      row_pixels = image[row, :cols]
      dut.cmp_o.value = get_cmp_o(row_pixels, threshold, len(dut.cmp_o))
    else:
      dut.cmp_o.value = 0

    await RisingEdge(dut.clk)

    if int(dut.frame_done.value) == 1 and np.array_equal(actual_mem2, expected_mem):
      dut._log.info(f"Frame after reset: frame_done at cycle {cycle}; Memory contents match")
      return

  assert int(dut.frame_done.value) == 1, "did not reach frame_done after mid-frame reset"
  assert np.array_equal(actual_mem2, expected_mem), \
    f"Memory mismatch after reset\nexpected: {expected_mem}\nactual:   {actual_mem2}"


# verify dark reference subtraction:
# pixels above dark_ref are reduced by dark_ref, pixels at or below clamp to 0
@cocotb.test()
async def dark_reference_test(dut):
  cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
  await reset_dut(dut)

  DARK_REF = 3  # simulated dark current level

  # image with pixels spanning: below, equal, and above dark_ref
  image = np.array([
    [0, 1, 3, 5],   # row 0: 0→0, 1→0, 3→0, 5→2
    [3, 3, 3, 3],   # row 1: all equal to dark_ref → all 0
    [0, 0, 0, 0],   # row 2: all below dark_ref → all 0
    [6, 7, 8, 9],   # row 3: all above → 3,4,5,6
  ], dtype=np.uint8)

  expected_mem = build_expected_memory_dark_ref(image, DARK_REF)
  actual_mem   = np.zeros_like(expected_mem, dtype=np.uint8)
  cocotb.start_soon(capture_dut_writes(dut, actual_mem))

  dut.frame_start.value = 1
  await ClockCycles(dut.clk, 1)
  dut.frame_start.value = 0

  for cycle in range(2_000_000):
    threshold = int(dut.duty_cycle.value)
    row = int(dut.current_row.value)

    cols = len(dut.cmp_o) - 1
    if row < image.shape[0]:
      row_pixels = image[row, :cols]
      dut.cmp_o.value = get_cmp_o(row_pixels, threshold, len(dut.cmp_o), DARK_REF)
    else:
      dut.cmp_o.value = 0

    await RisingEdge(dut.clk)

    if int(dut.frame_done.value) == 1 and np.array_equal(actual_mem, expected_mem):
      dut._log.info(f"Dark reference test passed at cycle {cycle}; Memory contents match")
      return

  assert int(dut.frame_done.value) == 1, "did not reach frame_done"
  assert np.array_equal(actual_mem, expected_mem), \
    f"Dark reference mismatch\nexpected: {expected_mem}\nactual:   {actual_mem}"



