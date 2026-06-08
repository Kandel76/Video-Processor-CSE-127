import cocotb
import numpy as np

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, First, Timer

CLK_PERIOD_NS = 40  # 25 MHz
test_image = "img_30x30_gradient.npy"

# Simulated off-chip Hitachi SRAM (address -> byte).
# Shared between coroutines; clear at the start of each test.
sram = {}


def load_img(filename):
    # loads from the shared 4x4 test images directory (../test_images/)
    return np.load(f"../test_images/{filename}")


def load_any_img(filepath, rows=240, cols=320):
    from PIL import Image
    img = Image.open(filepath).convert("L").resize((cols, rows), Image.LANCZOS)
    return (np.array(img, dtype=np.uint8) >> 4)  # 8-bit (0-255) → 4-bit (0-15)


async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.frame_start.value = 0
    dut.cmp_o.value = 0
    dut.mem_data_i.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


# ── Off-chip SRAM simulation ──────────────────────────────────────────────────
# Adapted from Ben's test_mem2vga.py.
# hmem_access uses nCS1_o for addresses 0x0000–0x7FFF,
#               and nCS2_o for addresses 0x8000–0xFFFF.

async def simulate_sram_chip1(dut):
    while True:
        action = await First(FallingEdge(dut.mem_nWE_o), FallingEdge(dut.mem_nOE_o))
        await Timer(1, unit="ps")  # settle past the edge before sampling control signals
        if dut.mem_nCS1_o.value != 0:
            continue
        addr = int(dut.mem_addr_o.value)
        await Timer(85, unit="ns")  # SRAM access time
        if action == FallingEdge(dut.mem_nWE_o):
            sram[addr] = int(dut.mem_data_o.value)
        if action == FallingEdge(dut.mem_nWE_o):
            sram[addr] = int(dut.mem_data_o.value)
            # dut._log.info(f"SRAM1 WRITE addr={addr} data={int(dut.mem_data_o.value)}")
        else:
            dut.mem_data_i.value = sram.get(addr, 0x00)


async def simulate_sram_chip2(dut):
    while True:
        action = await First(FallingEdge(dut.mem_nWE_o), FallingEdge(dut.mem_nOE_o))
        await Timer(1, unit="ps")
        if dut.mem_nCS2_o.value != 0:
            continue
        addr = int(dut.mem_addr_o.value)
        await Timer(85, unit="ns")
        if action == FallingEdge(dut.mem_nWE_o):
            sram[0x8000 | addr] = int(dut.mem_data_o.value)
        if action == FallingEdge(dut.mem_nWE_o):
            sram[0x8000 | addr] = int(dut.mem_data_o.value)
            # dut._log.info(f"SRAM2 WRITE addr={0x8000 | addr} data={int(dut.mem_data_o.value)}")
        else:
            dut.mem_data_i.value = sram.get(0x8000 | addr, 0x00)


# ── Comparator driver ─────────────────────────────────────────────────────────
# Mirrors get_cmp_o() from RTL/cocotb_backend/test_top.py.

def get_cmp_o(row_pixels, threshold, cmp_width, dark_ref=0):
    bits = ["0"] * cmp_width
    if dark_ref > threshold:
        bits[0] = "1"
    for col, pixel in enumerate(row_pixels):
        if int(pixel) > threshold:
            bits[col + 1] = "1"
    return "".join(reversed(bits))


# ── Sensor driver (runs as a background coroutine) ────────────────────────────

async def drive_sensor(dut, image, ROWS, COLS):
    dut.frame_start.value = 1
    await ClockCycles(dut.clk, 1)

    for _ in range(2_000_000):
        threshold = int(dut.duty_cycle.value)
        row = int(dut.current_row.value)
        # print(f"Sensor: row={row}, threshold={threshold}")
        if row < ROWS:
            row_pixels = image[row, :COLS] if row < image.shape[0] else []
            dut.cmp_o.value = get_cmp_o(row_pixels, threshold, COLS + 1)
        else:
            dut.cmp_o.value = 0
        await RisingEdge(dut.clk)
        if int(dut.frame_done.value) == 1:
            dut._log.info("Sensor: frame_done")
            return

    assert False, "Sensor timed out waiting for frame_done"

# ── Build expected values from the input image ────────────────────>

def expected_flat_image(image, ROWS, COLS):
    canvas = np.zeros((ROWS, COLS), dtype=np.uint8)
    r = min(image.shape[0], ROWS)
    c = min(image.shape[1], COLS)
    canvas[:r, :c] = image[:r, :c]
    return canvas.flatten()

# ── Read pixel values back from the simulated SRAM ────────────────────>
def read_sram_frame(ROWS, COLS):
    total_pixels = ROWS * COLS
    total_bytes = (total_pixels + 1) // 2

    pixels = []

    for addr in range(total_bytes):
        byte = sram.get(addr, 0)

        high_pixel = (byte >> 4) & 0xF
        low_pixel = byte & 0xF

        pixels.append(high_pixel)
        pixels.append(low_pixel)

    return np.array(pixels[:total_pixels], dtype=np.uint8)

# ── Tests ─────────────────────────────────────────────────────────────────────

@cocotb.test()
async def full_system_test(dut):
    """
    Single end-to-end test: sensor and mem2vga run concurrently, matching
    real hardware behaviour. The sensor drives comparators in the background
    while the main coroutine waits for frame_done then immediately captures
    the VGA output to vga_out_full_system.bmp.
    """
    # cmp_o is [COLS:0] in RTL, so its width always equals COLS+1 regardless of
    # whether the parameter survives elaboration into the simulation.
    COLS = len(dut.cmp_o) - 1
    ROWS = int(dut.ROWS.value) if hasattr(dut, 'ROWS') else COLS
    dut._log.info(f"Frame size from DUT: {ROWS} rows x {COLS} cols")

    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    sram.clear()
    cocotb.start_soon(simulate_sram_chip1(dut))
    cocotb.start_soon(simulate_sram_chip2(dut))

    image = load_img(test_image)

    # Sensor runs in background — mem2vga scans concurrently the whole time
    cocotb.start_soon(drive_sensor(dut, image, ROWS, COLS))

    # Wait for the sensor to finish writing the frame into SRAM
    await RisingEdge(dut.frame_done)
    dut._log.info("frame_done received — capturing next VGA frame")

    # Stop the scanner from restarting (frame_start=1 would trigger a new scan
    # the moment the scanner returns to IDLE, competing for SRAM during capture)
    dut.frame_start.value = 0

    # Let any in-flight hmem_access writes drain (pipeline is ~6 cycles deep)
    await ClockCycles(dut.clk, 20)

    # BMP header: 640x480, 24-bit colour, top-down (negative height = 0xFFFFFE20)
    # Top-down means first bytes in the file = top row of displayed image, which
    # matches our capture order (VGA line 0 first). Positive height = bottom-up,
    # which would flip the image.
    # File size = 54 (header) + 640*480*3 (pixels) = 921654 = 0x000E1036
    bmp_header = (
        bytearray([0x42, 0x4D, 0x36, 0x10, 0x0E, 0x00, 0x00, 0x00]) +
        bytearray([0x00, 0x00, 0x36, 0x00, 0x00, 0x00, 0x28, 0x00]) +
        bytearray([0x00, 0x00, 0x80, 0x02, 0x00, 0x00, 0x20, 0xFE]) +  # height = -480
        bytearray([0xFF, 0xFF, 0x01, 0x00, 0x18, 0x00, 0x00, 0x00]) +
        bytearray([0x00, 0x00, 0x00, 0x6C, 0x09, 0x00, 0x13, 0x0B]) +
        bytearray([0x00, 0x00, 0x13, 0x0B, 0x00, 0x00, 0x00, 0x00]) +
        bytearray([0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    )

    # Sync to a frame boundary so the 480 captured lines form one complete frame.
    # Without this, capture starts mid-frame: big_pix_addr resets at the vsync
    # boundary mid-capture, causing the image to split/jump in the middle of the BMP.
    await RisingEdge(dut.vsync_o)
    await FallingEdge(dut.vsync_o)

    with open("vga_out_full_system.bmp", "wb") as f:
        f.write(bmp_header)

        for _ in range(480):
            await RisingEdge(dut.active_o)
            # pixel_o is 1 clock behind active_o (pixel_r is registered from pixel_n
            # which uses active_o; at the posedge where active_o rises, pixel_r still
            # holds the pre-rise value = 0). Advance one clock so pixel_o is valid.
            await RisingEdge(dut.clk)
            for _ in range(640):
                await FallingEdge(dut.clk)
                byte = int(dut.pixel_o.value) & 0xF0
                f.write(bytearray([byte, byte, byte]))

    dut._log.info("VGA frame written to vga_out_full_system.bmp")

@cocotb.test()
async def full_sys_sram_check_test(dut):
    """
    verify that the expected image data is written into SRAM
    """
    COLS = len(dut.cmp_o) - 1
    ROWS = int(dut.ROWS.value) if hasattr(dut, 'ROWS') else COLS
    dut._log.info(f"SRAM check: {ROWS} rows x {COLS} cols")
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    sram.clear()

    cocotb.start_soon(simulate_sram_chip1(dut))
    cocotb.start_soon(simulate_sram_chip2(dut))

    image = load_img(test_image)

    cocotb.start_soon(drive_sensor(dut, image, ROWS, COLS))

    # wait for the frame to be fully written to SRAM
    await RisingEdge(dut.frame_done)
    await ClockCycles(dut.clk, 10)

    # compare expected image pixels to SRAM's
    expected = expected_flat_image(image, ROWS, COLS)
    actual = read_sram_frame(ROWS, COLS)

    dut._log.info(f"Expected SRAM: {expected}")
    dut._log.info(f"Actual SRAM:   {actual}")

    assert np.array_equal(actual, expected), (
        f"SRAM mismatch\n"
        f"Expected: {expected}\n"
        f"Got:      {actual}"
    )

    dut._log.info("SRAM output matches expected image")

