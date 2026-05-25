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


async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.frame_start.value = 0
    dut.cmp_o.value = 0
    dut.mem_data_i.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


# ── Off-chip SRAM simulation ──────────────────────────────────────────────────
# Adapted from VGA/mem2vga/cocotb/test_mem2vga.py.
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


# ── Tests ─────────────────────────────────────────────────────────────────────

@cocotb.test()
async def smoke_test(dut):
    """
    End-to-end smoke test
    1.Run the image sensor until frame_done is asserted.
    2.Verify VGA sync is live: active_o pulses 3 times.
    """
    ROWS = int(dut.ROWS.value)
    COLS = int(dut.COLS.value)
    dut._log.info(f"Frame size from DUT: {ROWS} rows x {COLS} cols")

    cocotb.start_soon(Clock(dut.clk,     CLK_PERIOD_NS,     unit="ns").start())

    await reset_dut(dut)

    sram.clear()
    #runs in the background
    cocotb.start_soon(simulate_sram_chip1(dut))
    cocotb.start_soon(simulate_sram_chip2(dut))

    image = load_img(test_image)

    dut.frame_start.value = 1
    await ClockCycles(dut.clk, 1)
    dut.frame_start.value = 0

    # Drive comparators until frame_done
    for cycle in range(2_000_000):
        threshold = int(dut.duty_cycle.value)
        row = int(dut.current_row.value)
        if row < image.shape[0]:
            dut.cmp_o.value = get_cmp_o(image[row, :COLS], threshold, COLS + 1)
        else:
            dut.cmp_o.value = 0
        await RisingEdge(dut.clk)
        if int(dut.frame_done.value) == 1:
            dut._log.info(f"frame_done at cycle {cycle}")
            break
    else:
        assert False, "Timed out waiting for frame_done"

    # Verify VGA sync: active_o pulses 3 times
    for pulse in range(3):
        for _ in range(1_000_000):
            await RisingEdge(dut.clk)
            if int(dut.active_o.value) == 1:
                break
        else:
            assert False, f"active_o never went high (pulse {pulse})"
        for _ in range(1_000_000):
            await RisingEdge(dut.clk)
            if int(dut.active_o.value) == 0:
                break
        else:
            assert False, f"active_o never went low (pulse {pulse})"

    dut._log.info("VGA active_o pulsed 3 times — full pipeline running")


@cocotb.test()
async def vga_capture_test(dut):
    """
    Capture one full VGA frame to vga_out_full_system.bmp.

    Run with ROWS=240, COLS=320 top parameters for a real image.
    With ROWS=4 / COLS=4 the BMP will be mostly black except for the
    top-left corner where the 4x4 sensor data lands.
    """
    ROWS = int(dut.ROWS.value)
    COLS = int(dut.COLS.value)
    dut._log.info(f"Frame size from DUT: {ROWS} rows x {COLS} cols")

    cocotb.start_soon(Clock(dut.clk,     CLK_PERIOD_NS,     unit="ns").start())

    await reset_dut(dut)

    sram.clear()
    cocotb.start_soon(simulate_sram_chip1(dut))
    cocotb.start_soon(simulate_sram_chip2(dut))

    image = load_img(test_image)

    dut.frame_start.value = 1
    await ClockCycles(dut.clk, 1)
    dut.frame_start.value = 0

    for cycle in range(2_000_000):
        threshold = int(dut.duty_cycle.value)
        row = int(dut.current_row.value)
        if row < image.shape[0]:
            dut.cmp_o.value = get_cmp_o(image[row, :COLS], threshold, COLS + 1)
        else:
            dut.cmp_o.value = 0
        await RisingEdge(dut.clk)
        if int(dut.frame_done.value) == 1:
            dut._log.info(f"Sensor frame_done at cycle {cycle}, waiting for VGA scan-out")
            break
    else:
        assert False, "Timed out waiting for frame_done"

    # BMP header: 640x480, 24-bit color (same format as VGA/mem2vga/cocotb/test_mem2vga.py)
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
        # Iterating j from 479→0 while awaiting each active_o rising edge
        # maps VGA line 0 → BMP row 479 (bottom) and VGA line 479 → BMP row 0 (top).
        for _ in range(479, -1, -1):
            await RisingEdge(dut.active_o)
            for _ in range(639, -1, -1):
                await FallingEdge(dut.clk)
                await Timer(1, unit="ps")
                byte = int(dut.pixel_o.value) & 0xF0
                f.write(bytearray([byte, byte, byte]))

    dut._log.info("VGA frame written to vga_out_full_system.bmp")
