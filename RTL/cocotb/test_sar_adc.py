import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

CLK_PERIOD_NS = 10

# FSM encodings from sar_adc.sv
IDLE = 0b000
SAMPLE = 0b001
UPDATE = 0b010
WAIT = 0b011
SEND = 0b100

# helper functions

#state machine states
def state_name(v):
    return {
        IDLE: "IDLE",
        SAMPLE: "SAMPLE",
        UPDATE: "UPDATE",
        WAIT: "WAIT",
        SEND: "SEND",
    }.get(v, f"UNKNOWN({v})")


def get_state(dut):
    return int(dut.state.value)


def assert_state(dut, expected, msg=""):
    got = get_state(dut)
    assert got == expected, f"{msg} expected {state_name(expected)}, got {state_name(got)}"

#resets adc
async def reset_dut(dut):
    dut.read_en.value = 0
    dut.cmp_o.value = 0
    dut.valid_voltage.value = 0
    dut.adc_reset.value = 0
    dut.reset_signal.value = 1

    await ClockCycles(dut.clk, 2)
    dut.reset_signal.value = 0
    await ClockCycles(dut.clk, 2)

    assert_state(dut, IDLE, "After reset:")
    assert int(dut.adc_o.value) == 0
    assert int(dut.adc_done.value) == 0
    assert int(dut.adc_ready.value) == 1
    assert int(dut.comp_done.value) == 0

async def do_conversion_step(dut, cmp_value=1, first_step=False):
    #comparator high 1, (does 1 cycle of this here)
    # first_step=1 means leave IDLE using read_en
    if first_step:
        assert_state(dut, IDLE, "First conversion step should begin in IDLE:")

    dut.cmp_o.value = cmp_value
    dut.read_en.value = 1 if first_step else 0

    # valid voltage high so ADC can SAMPLE cmp_o
    dut.valid_voltage.value = 1
    await RisingEdge(dut.clk)
    assert_state(dut, SAMPLE, "Expected to enter SAMPLE:")

    dut.read_en.value = 0

    # keep valid high for one more cycle so sample can happen
    await RisingEdge(dut.clk)
    assert_state(dut, SAMPLE, "Expected to remain in SAMPLE while valid is high:")

    # drop valid low so SAMPLE goes to UPDATE
    dut.valid_voltage.value = 0
    await RisingEdge(dut.clk)
    assert_state(dut, UPDATE, "Expected SAMPLE->UPDATE:")
    assert int(dut.comp_done.value) == 1, "comp_done should pulse during UPDATE"

    # one cycle later UPDATE should advance to WAIT or SEND
    await RisingEdge(dut.clk)
    assert get_state(dut) in (WAIT, SEND), "Expected UPDATE->WAIT/SEND"


# model PWM + comparator behavior using threshold
async def run_pixel_model(dut, pixel_value):
   
    for threshold in range(16):
        cmp_value = 1 if pixel_value > threshold else 0
        await do_conversion_step(dut, cmp_value=cmp_value, first_step=(threshold == 0))
        if cmp_value == 0:
            break

    await ClockCycles(dut.clk, 2)

    got = int(dut.adc_o.value)
    assert got == pixel_value, f"ERROR: pixel={pixel_value}, expected ADC {pixel_value}, got {got}"


async def drive_to_send(dut):
    # Reach code=15, then one more cmp=1 step pushes to SEND
    for i in range(15):
        await do_conversion_step(dut, cmp_value=1, first_step=(i == 0))
        assert_state(dut, WAIT, f"Expected WAIT after increment step {i}:")

    await do_conversion_step(dut, cmp_value=1, first_step=False)
    assert_state(dut, SEND, "Expected SEND at terminal count:")


# tests follow below


@cocotb.test()
#test checks the adc final value
async def test_sar_adc_final_result(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())

    # test 1 -------------------------
    await reset_dut(dut)
    print(" --- ADC target code 3 test --- ")

    target_code = 3

    for i in range(target_code):
        await do_conversion_step(dut, cmp_value=1, first_step=(i == 0))
        assert int(dut.adc_done.value) == 0
        assert int(dut.adc_ready.value) == 0

    await do_conversion_step(dut, cmp_value=0, first_step=False)
    assert int(dut.adc_o.value) == target_code, (
        f"ERROR: expected value {target_code}, got value {int(dut.adc_o.value)}"
    )

    # test 2 -------------------------
    await reset_dut(dut)
    print(" --- ADC target code 5 test --- ")

    target_code = 5

    for i in range(target_code):
        await do_conversion_step(dut, cmp_value=1, first_step=(i == 0))
        assert int(dut.adc_done.value) == 0
        assert int(dut.adc_ready.value) == 0

    await do_conversion_step(dut, cmp_value=0, first_step=False)
    assert int(dut.adc_o.value) == target_code, (
        f"ERROR: expected value {target_code}, got value {int(dut.adc_o.value)}"
    )


@cocotb.test()
async def test_sar_adc_static_img(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())

    try:
        img = np.load("../../test_images/img2_gradient.npy")
    except FileNotFoundError:
        dut._log.warning("Skipping static image test: ../../test_images/img2_gradient.npy missing")
        return

    pixels = img.flatten()
    print(" ___ ADC static img test: gradient 4x4 ___ ")

    for idx, pixel in enumerate(pixels):
        target_code = int(pixel)

        await reset_dut(dut)
        await run_pixel_model(dut, target_code)

        got = int(dut.adc_o.value)

        print(f"pixel {idx}: target={target_code}, got={got}")
        assert got == target_code, f"ERROR at pixel {idx}: expected {target_code}, got {got}"


@cocotb.test()
#tests state transitions
async def test_sar_adc_fsm_transitions(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    # IDLE -> IDLE when read_en is low
    dut.read_en.value = 0
    dut.valid_voltage.value = 0
    await RisingEdge(dut.clk)
    assert_state(dut, IDLE, "IDLE should hold when read_en=0:")

    # IDLE -> SAMPLE when read_en && valid_voltage
    dut.read_en.value = 1
    dut.valid_voltage.value = 1
    await RisingEdge(dut.clk)
    assert_state(dut, SAMPLE, "IDLE->SAMPLE failed:")

    # SAMPLE -> SAMPLE while valid high
    dut.read_en.value = 0
    await RisingEdge(dut.clk)
    assert_state(dut, SAMPLE, "SAMPLE should hold while valid is high:")

    # SAMPLE -> UPDATE when valid low
    dut.valid_voltage.value = 0
    await RisingEdge(dut.clk)
    assert_state(dut, UPDATE, "SAMPLE->UPDATE failed:")

    # UPDATE -> WAIT
    await RisingEdge(dut.clk)
    assert_state(dut, WAIT, "UPDATE->WAIT failed:")

    # WAIT -> WAIT when valid low
    await RisingEdge(dut.clk)
    assert_state(dut, WAIT, "WAIT should hold while valid is low:")

    # WAIT -> SAMPLE when valid high
    dut.valid_voltage.value = 1
    await RisingEdge(dut.clk)
    assert_state(dut, SAMPLE, "WAIT->SAMPLE failed:")


@cocotb.test()
#sticky (meaning we are stuck there)
async def test_sar_adc_send_state_sticky(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    await drive_to_send(dut)
    assert int(dut.adc_done.value) == 1, "adc_done should be high in SEND"

    for _ in range(3):
        await RisingEdge(dut.clk)
        assert_state(dut, SEND, "SEND should remain sticky:")
        assert int(dut.adc_done.value) == 1, "adc_done should stay high in SEND"


@cocotb.test()
#reset whilst we are working (this should only happen if we manually reset our chip)
async def test_resets_from_active_states(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    # Move into SAMPLE
    dut.read_en.value = 1
    dut.valid_voltage.value = 1
    await RisingEdge(dut.clk)
    assert_state(dut, SAMPLE, "Expected SAMPLE before global reset:")

    # Global reset from SAMPLE
    dut.reset_signal.value = 1
    await ClockCycles(dut.clk, 1)
    dut.reset_signal.value = 0
    await ClockCycles(dut.clk, 1)
    assert_state(dut, IDLE)
    assert int(dut.adc_o.value) == 0

    # Move into WAIT, then adc_reset
    await do_conversion_step(dut, cmp_value=1, first_step=True)
    assert_state(dut, WAIT, "Expected WAIT before adc_reset:")
    dut.adc_reset.value = 1
    await ClockCycles(dut.clk, 1)
    dut.adc_reset.value = 0
    await ClockCycles(dut.clk, 1)
    assert_state(dut, IDLE)
    assert int(dut.adc_done.value) == 0
    assert int(dut.comp_done.value) == 0
    assert int(dut.adc_ready.value) == 1

