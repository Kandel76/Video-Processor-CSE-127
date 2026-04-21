import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

CLK_PERIOD_NS = 10

# helpers ---------------------------------------

async def reset_dut(dut):
    dut.read_en.value = 0
    dut.cmp_o.value = 0
    dut.valid_voltage.value = 0
    dut.reset_signal.value = 1

    await ClockCycles(dut.clk, 2)
    dut.reset_signal.value = 0
    await ClockCycles(dut.clk, 2)

async def do_conversion_step(dut, cmp_value=1, first_step=False):
    # one sample /  update step
    #first_step=1 means leave IDLE using read_en

    dut.cmp_o.value = cmp_value

    if first_step:
        dut.read_en.value = 1
    else:
        dut.read_en.value = 0

    #valid voltage high so ADC can SAMPLE cmp_o
    dut.valid_voltage.value = 1
    await RisingEdge(dut.clk)

    dut.read_en.value = 0

    #keep valid high for one more cycle so sample can happen
    await RisingEdge(dut.clk)

    #drop valid low so SAMPLE goes to UPDATE
    dut.valid_voltage.value = 0
    await RisingEdge(dut.clk)

async def run_target_code(dut, target_code): 
    #increment for target_code steps, then stop with cmp_o = 0
    for i in range(target_code):
        await do_conversion_step(dut, cmp_value = 1, first_step = (i == 0))
        
    await do_conversion_step(dut, cmp_value = 0, first_step = (target_code == 0))
    
    await ClockCycles(dut.clk, 4)
    
    got = int(dut.adc_o.value)
    assert got == target_code, f"!!! ERROR: expected value {target_code}, got value {int(got)}"

# tests -------------------------------------------

@cocotb.test()
async def test_sar_adc_final_result(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())

    # test 1 -------------------------
    await reset_dut(dut)
    print(" --- ADC target code 3 test --- ")

    target_code = 3

    for i in range(target_code):
        await do_conversion_step(dut, cmp_value=1, first_step=(i == 0))

    await do_conversion_step(dut, cmp_value=0, first_step=False)

    await ClockCycles(dut.clk, 4)

    assert int(dut.adc_o.value) == target_code, \
        f"!!! ERROR: expected value {target_code}, got value {int(dut.adc_o.value)}"

    # test 2 -------------------------
    await reset_dut(dut)
    print(" --- ADC target code 5 test --- ")

    target_code = 5

    for i in range(target_code):
        await do_conversion_step(dut, cmp_value=1, first_step=(i == 0))

    await do_conversion_step(dut, cmp_value=0, first_step=False)

    await ClockCycles(dut.clk, 4)

    assert int(dut.adc_o.value) == target_code, \
        f"!!! ERROR: expected value {target_code}, got value {int(dut.adc_o.value)}"

    await ClockCycles(dut.clk, 6)

@cocotb.test()
async def test_sar_adc_static_img(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    
    img = np.load("../../test_images/img2_gradient.npy")
    pixels = img.flatten()
    
    print(" ___ ADC static img test: gradient 4x4 ___ ")
    
    for idx, pixel in enumerate(pixels):
        target_code = int(pixel)
        
        await reset_dut(dut)
        await run_target_code(dut, target_code)
        
        got = int(dut.adc_o.value)
        
        print(f"pixel {idx}: target:{target_code}, got={got}")
        assert got == target_code, f"ERROR at pixel {idx}: expected {target_code}, got {got}"
        
    await ClockCycles(dut.clk, 6)





                      
