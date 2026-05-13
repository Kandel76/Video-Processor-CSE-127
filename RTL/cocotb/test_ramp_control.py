import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, NextTimeStep, ClockCycles

# RC value cycle time
RAMP_TIME = 213

CLK_PERIOD_NS = 10

#ramp controller state machine states
IDLE = 0b00
VOLTAGE_RAMP = 0b01
WAIT = 0b10
FINISH = 0b11

#helper functions
async def clk_rising_ro(dut):
    await RisingEdge(dut.clk)
    await ReadOnly()
    await NextTimeStep()


def state_name(v):
    return {
        IDLE: "IDLE",
        VOLTAGE_RAMP: "VOLTAGE_RAMP",
        WAIT: "WAIT",
        FINISH: "FINISH",
    }.get(v, f"UNKNOWN({v})")


def get_state(dut):
    return int(dut.state.value)


def assert_state(dut, expected, msg=""):
    got = get_state(dut)
    assert got == expected, f"{msg} expected {state_name(expected)}, got {state_name(got)}"


async def wait_state(dut, expected, msg="", max_cycles=RAMP_TIME):
    for _ in range(max_cycles):
        await clk_rising_ro(dut)
        if get_state(dut) == expected:
            return
    assert False, f"{msg} timeout waiting for {state_name(expected)}"

#same as adc testbench reset function
async def reset_dut(dut):
    dut.comp_done.value = 0
    dut.adc_start.value = 0
    dut.global_reset.value = 1

    await ClockCycles(dut.clk, 2)
    dut.global_reset.value = 0
    await ClockCycles(dut.clk, 2)
    await ReadOnly()

    assert_state(dut, IDLE, "After reset:")
    assert int(dut.duty_cycle.value) == 0
    assert int(dut.ramp_counter.value) == 0
    assert int(dut.valid_voltage.value) == 0
    assert int(dut.reset_adc.value) == 0
    assert int(dut.last_step.value) == 0
    await NextTimeStep()

#similar to first conversion step from adc testbench
async def enter_first_wait(dut):
    dut.adc_start.value = 1
    await clk_rising_ro(dut)
    assert_state(dut, VOLTAGE_RAMP, "IDLE->VOLTAGE_RAMP:")
    dut.adc_start.value = 0
    await wait_state(dut, WAIT, "ramp->WAIT")

#resets and asserts reset signals
@cocotb.test()
async def test_ramp_control_reset(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

#tests idle and start states
@cocotb.test()
async def test_ramp_control_initialization(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    dut.adc_start.value = 0
    await clk_rising_ro(dut)
    assert_state(dut, IDLE, "IDLE with adc_start = 0:")

    dut.adc_start.value = 1
    await clk_rising_ro(dut)
    assert_state(dut, VOLTAGE_RAMP, "adc_start -> VOLTAGE_RAMP:")
    dut.adc_start.value = 0

#simple test to make sure we stay in wait for n cycles 
@cocotb.test()
async def test_ramp_control_wait_hold(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)
    await enter_first_wait(dut)

    dut.comp_done.value = 0
    for _ in range(4):
        await clk_rising_ro(dut)
        assert_state(dut, WAIT, "WAIT should hold without comp_done:")

#tests all the state transitions
@cocotb.test()
async def test_ramp_control_fsm_transitions(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)
    await enter_first_wait(dut)

    assert int(dut.duty_cycle.value) == 0
    assert int(dut.last_step.value) == 0

    dut.comp_done.value = 1
    await clk_rising_ro(dut)
    assert_state(dut, VOLTAGE_RAMP, "WAIT->VOLTAGE_RAMP:")
    dut.comp_done.value = 0
    assert int(dut.duty_cycle.value) == 1

    await wait_state(dut, WAIT, "second ramp->WAIT")
    assert int(dut.duty_cycle.value) == 1
    assert int(dut.last_step.value) == 0

    while int(dut.duty_cycle.value) != 15:
        dut.comp_done.value = 1
        await clk_rising_ro(dut)
        dut.comp_done.value = 0
        assert_state(dut, VOLTAGE_RAMP, "mid-row WAIT->RAMP:")
        await wait_state(dut, WAIT, "mid-row RAMP->WAIT:")
    assert int(dut.last_step.value) == 1

#tests the entire 16 cycles (min-max duty cycle)
@cocotb.test()
async def test_ramp_control_full_row(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    dut.adc_start.value = 0
    await clk_rising_ro(dut)
    assert_state(dut, IDLE, "IDLE hold:")

    dut.adc_start.value = 1
    await clk_rising_ro(dut)
    assert_state(dut, VOLTAGE_RAMP, "IDLE->VOLTAGE_RAMP:")
    dut.adc_start.value = 0

    await wait_state(dut, WAIT, "first ramp->WAIT")
    assert int(dut.duty_cycle.value) == 0
    assert int(dut.last_step.value) == 0

    for d in range(15):
        assert_state(dut, WAIT, f"WAIT d={d}:")
        assert int(dut.duty_cycle.value) == d
        assert int(dut.last_step.value) == 0

        dut.comp_done.value = 1
        await clk_rising_ro(dut)
        assert_state(dut, VOLTAGE_RAMP, f"comp d={d}:")
        dut.comp_done.value = 0

        await wait_state(dut, WAIT, f"ramp after d={d}:")
        assert int(dut.duty_cycle.value) == d + 1

    assert_state(dut, WAIT, "terminal WAIT:")
    assert int(dut.duty_cycle.value) == 15
    assert int(dut.last_step.value) == 1

    dut.comp_done.value = 1
    await clk_rising_ro(dut)
    dut.comp_done.value = 0
    assert_state(dut, FINISH, "WAIT->FINISH:")

    await clk_rising_ro(dut)
    assert_state(dut, IDLE, "FINISH->IDLE:")
    assert int(dut.reset_adc.value) == 1

    await clk_rising_ro(dut)
    assert_state(dut, IDLE, "IDLE stable:")
    assert int(dut.duty_cycle.value) == 0
    assert int(dut.reset_adc.value) == 0
    assert int(dut.last_step.value) == 0

#test to ensure reset works throughout the system 
@cocotb.test()
async def test_ramp_control_reset_from_active(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)
    await enter_first_wait(dut)

    dut.global_reset.value = 1
    await ClockCycles(dut.clk, 1)
    dut.global_reset.value = 0
    await ClockCycles(dut.clk, 1)
    await ReadOnly()
    assert_state(dut, IDLE, "global_reset from WAIT:")
    assert int(dut.duty_cycle.value) == 0
    await NextTimeStep()
