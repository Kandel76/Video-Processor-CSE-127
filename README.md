# Video-Processor-CSE-127

**ADC-COMPARATOR-DAC-DIODE INTERFACE**
<img width="1376" height="832" alt="image" src="https://github.com/user-attachments/assets/68dd7038-7724-41c2-918e-15bb323f2835" />
_Part of our Video-Processor Design, this section details the construction and apparent interface of the listed modules and their importance surrounding Video-Processing (On-Chip)_

**ADC** (Analog-Digital Converter)

## Comparator Overview

The comp_gf180.sp file simulates a clocked comparator implemented with the GF180MCU standard-cell logic gates. The comparator is intended for use inside a Successive Approximation Register (SAR) ADC, where it makes the decision:

    Vin (sampled photodiode signal)  ?  Vtest (CDAC output)

This simulation is intended for:

- Comparator functionality validation
- SAR ADC architecture testing
- Offset estimation
- UCSC Academic research and coursework

It is not intended for final silicon verification.

## Concept Overview:

    Photodiode → Sample/Hold (Vin) → Comparator ← CDAC (Vtest)
                                           ↓
                                         SAR Logic

In this simulation:
- `vinp` is the sampled photodiode voltage.
- `vinm` is the CDAC comparison voltage.
- The comparator resolves the differential input and outputs `q` and `qb`.

## Comparator Architecture
<img width="1376" height="832" alt="image" src="/comparator/gf130_comp/images/comparator.png" />

## Offset Extraction Method

Offset is estimated in Python.

Method:

1. Detect clock falling edges.
2. Sample `q` and `qb` after a small settle delay.
3. Define decision:

       decision = (q > qb)

4. Detect the first 0 → 1 transition.
5. Estimate threshold voltage:

       V_threshold = first Vinp where decision becomes HIGH

6. Compute input-referred offset:

       Offset (mV) = (V_threshold − Vinm) × 1000

## How to Run

Execute:

    ngspice -b tb_comp_3v3.sp

Then run the Python analysis script to generate:

- Decision vs Vinp plot
- Estimated comparator offset (mV)

**DAC** (Digital-Analog Converter)

**Diode Interface**
