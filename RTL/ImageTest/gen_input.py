#!/usr/bin/env python3
"""

Creates a test input for img_tb.sv
takes a regular image and turn it into a hex file for the testbench
saves a reference array for later comparison


"""



"""

Usage:
  python3 gen_input.py                          # gradient, dark ref = 0
  python3 gen_input.py path/to/image.png        # real image, dark ref = 0
  python3 gen_input.py --dark 3                 # gradient, dark ref = 3
  python3 gen_input.py photo.png --dark 5       # real image, dark ref = 5

The dark reference is placed in adc_data[3:0].  The scanner subtracts it
from every column:  output = max(raw - dark, 0).  The saved input_ref.npy
already reflects this subtraction so check_output.py needs no changes.

Outputs:
  input_pixels.hex   — one 1284-bit hex value per row (321 nibbles), read by $readmemh
  input_ref.npy      — uint8 array [ROWS, COLS] of expected post-subtraction values
  input_preview.png  — visual preview of what we expect the simulator to output

Requires: numpy, Pillow  (pip install numpy pillow)
"""

import argparse
import sys
import numpy as np

ROWS      = 240
COLS      = 320
DATA_BITS = 4
ADC_BANKS = COLS
NIBBLES   = DATA_BITS * (ADC_BANKS + 1) // 4  # 321  (1 dark-ref + 320 pixel columns)


def pixels_to_hex(pixels_4bit: np.ndarray, dark: int) -> list[str]:
    """Pack a [ROWS, COLS] uint8 array (values 0-15) into one hex string per row.

    adc_data layout (LSB first):
      bits [3:0]       = dark reference
      bits [7:4]       = column 0
      bits [11:8]      = column 1
      ...
      bits [1283:1280] = column 319
    """
    lines = []
    for row in pixels_4bit:
        val = dark & 0xF  # dark reference in bits [3:0]
        for col_idx, pval in enumerate(row):
            val |= (int(pval) << ((col_idx + 1) * 4))
        lines.append(f"{val:0{NIBBLES}x}")
    return lines


def make_gradient() -> np.ndarray:
    """4x4-block gradient test pattern (0-15 tiled across the frame)."""
    pixels = np.zeros((ROWS, COLS), dtype=np.uint8)
    for r in range(ROWS):
        for c in range(COLS):
            pixels[r, c] = ((r // (ROWS // 16)) * 1 + (c // (COLS // 16)) * 1) % 16
    return pixels


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image", nargs="?", help="input PNG (omit for gradient pattern)")
    parser.add_argument("--dark", type=int, default=0,
                        metavar="N", help="dark reference value 0-15 (default 0)")
    args = parser.parse_args()

    if not 0 <= args.dark <= 15:
        print(f"ERROR: --dark must be 0-15, got {args.dark}")
        sys.exit(1)

    if args.image:
        try:
            from PIL import Image
        except ImportError:
            print("ERROR: Pillow is required to load images.  pip install pillow")
            sys.exit(1)
        img = Image.open(args.image).convert("L").resize((COLS, ROWS), Image.LANCZOS)
        pixels_8bit = np.array(img, dtype=np.uint8)
        pixels_4bit = (pixels_8bit >> 4).astype(np.uint8)  # 0-255 → 0-15
        print(f"Loaded {args.image}  →  resized to {COLS}×{ROWS}, scaled to 4-bit")
    else:
        pixels_4bit = make_gradient()
        print(f"No image given — using built-in gradient test pattern ({COLS}×{ROWS}, 4-bit)")

    print(f"Dark reference = {args.dark}  (adc_data[3:0])")

    # Write hex file consumed by $readmemh in the testbench
    hex_lines = pixels_to_hex(pixels_4bit, args.dark)
    with open("input_pixels.hex", "w") as f:
        f.write("\n".join(hex_lines) + "\n")
    print(f"Written input_pixels.hex  ({ROWS} rows × {NIBBLES} nibbles each)")

    # Expected output after scanner dark-current subtraction: max(raw - dark, 0)
    ref = np.clip(pixels_4bit.astype(np.int16) - args.dark, 0, 15).astype(np.uint8)
    np.save("input_ref.npy", ref)
    print("Written input_ref.npy  (dark-subtracted expected values)")

    # Save a visual preview (scale 4-bit → 8-bit for PNG)
    try:
        from PIL import Image
        preview = Image.fromarray((ref * 17).astype(np.uint8))
        preview.save("input_preview.png")
        print("Written input_preview.png  (visual preview of expected output)")
    except ImportError:
        pass  # not fatal — just skip the preview


if __name__ == "__main__":
    main()
