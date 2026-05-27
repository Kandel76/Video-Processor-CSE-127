import cocotb
import numpy as np

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, First, Timer

CLK_PERIOD_NS = 40  # 25 MHz
test_image = "img2_gradient.npy"

# Simulated off-chip Hitachi SRAM (address -> byte).
# Shared between coroutines; clear at the start of each test.
sram = {}


def load_img(filename):
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
        print(f"Sensor: row={row}, threshold={threshold}")
        if row < ROWS:
            dut.cmp_o.value = get_cmp_o(image[row, :COLS], threshold, COLS + 1)
        else:
            dut.cmp_o.value = 0
        await RisingEdge(dut.clk)
        if int(dut.frame_done.value) == 1:
            dut._log.info("Sensor: frame_done")
            return

    assert False, "Sensor timed out waiting for frame_done"


# ── Tests ─────────────────────────────────────────────────────────────────────

@cocotb.test()
async def full_system_test(dut):
    """
    Single end-to-end test: sensor and mem2vga run concurrently, matching
    real hardware behaviour. The sensor drives comparators in the background
    while the main coroutine waits for frame_done then immediately captures
    the VGA output to vga_out_full_system.bmp.
    """
    ROWS = int(dut.ROWS.value)
    COLS = int(dut.COLS.value)
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

    # BMP header: 640x480, 24-bit colour
    bmp_header = (
        bytearray([0x42, 0x4D, 0x36, 0x6C, 0x00, 0x00, 0x00, 0x00]) +
        bytearray([0x00, 0x00, 0x36, 0x00, 0x00, 0x00, 0x28, 0x00]) +
        bytearray([0x00, 0x00, 0x80, 0x02, 0x00, 0x00, 0xE0, 0x01]) +
        bytearray([0x00, 0x00, 0x01, 0x00, 0x18, 0x00, 0x00, 0x00]) +
        bytearray([0x00, 0x00, 0x00, 0x6C, 0x09, 0x00, 0x13, 0x0B]) +
        bytearray([0x00, 0x00, 0x13, 0x0B, 0x00, 0x00, 0x00, 0x00]) +
        bytearray([0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    )

    with open("vga_out_full_system.bmp", "wb") as f:
        f.write(bmp_header)


        # BMP stores rows bottom-to-top; VGA scans top-to-bottom.
        # Iterating from 479→0 while awaiting each active_o rising edge
        # maps VGA line 0 → BMP row 479 (bottom) and VGA line 479 → BMP row 0 (top).
        for _ in range(479, -1, -1):
            await RisingEdge(dut.active_o)
            for _ in range(639, -1, -1):
                await FallingEdge(dut.clk)
                await Timer(1, unit="ps")
                byte = int(dut.pixel_o.value) & 0xF0
                f.write(bytearray([byte, byte, byte]))

    dut._log.info("VGA frame written to vga_out_full_system.bmp")
