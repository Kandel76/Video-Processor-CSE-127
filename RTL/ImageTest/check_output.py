#!/usr/bin/env python3
"""
check_output.py  —  reconstruct the simulator output and compare to the reference.

Usage:
  python3 check_output.py                          # uses default file names
  python3 check_output.py output.hex ref.npy       # custom paths

Inputs:
  output_pixels.hex  — one byte per line (hex), written by img_tb.sv
  input_ref.npy      — [ROWS, COLS] uint8 array of 4-bit values, written by gen_input.py

Outputs:
  output_image.png   — reconstructed image from simulator output
  diff.png           — absolute difference map (only written if there are errors)

Requires: numpy, Pillow  (pip install numpy pillow)
"""

import sys
import numpy as np

ROWS         = 240
COLS         = 320
BYTES_PER_ROW = COLS // 2   # two 4-bit pixels packed per byte
TOTAL_BYTES  = ROWS * BYTES_PER_ROW


def read_output_hex(path: str) -> np.ndarray:
    """Parse simulator output hex file into a [ROWS, COLS] uint8 pixel array."""
    with open(path) as f:
        raw = [int(line.strip(), 16) for line in f if line.strip()]

    if len(raw) != TOTAL_BYTES:
        raise ValueError(f"Expected {TOTAL_BYTES} bytes, got {len(raw)} in {path}")

    pixels = np.zeros((ROWS, COLS), dtype=np.uint8)
    for row in range(ROWS):
        for b in range(BYTES_PER_ROW):
            byte = raw[row * BYTES_PER_ROW + b]
            pixels[row, 2 * b]     = byte & 0xF         # column 2*b   (low nibble)
            pixels[row, 2 * b + 1] = (byte >> 4) & 0xF  # column 2*b+1 (high nibble)
    return pixels


def main():
    output_hex = sys.argv[1] if len(sys.argv) > 1 else "output_pixels.hex"
    ref_npy    = sys.argv[2] if len(sys.argv) > 2 else "input_ref.npy"

    try:
        from PIL import Image
        pil_ok = True
    except ImportError:
        pil_ok = False
        print("WARNING: Pillow not found — skipping PNG output.  pip install pillow")

    # ----------------------------------------------------------------
    # Load and reconstruct simulator output
    # ----------------------------------------------------------------
    output_pixels = read_output_hex(output_hex)
    print(f"Loaded {output_hex}  →  {ROWS}×{COLS} pixels, values {output_pixels.min()}–{output_pixels.max()}")

    if pil_ok:
        out_img = (output_pixels * 17).astype(np.uint8)   # scale 0-15 → 0-255
        Image.fromarray(out_img).save("output_image.png")
        print("Written output_image.png")

    # ----------------------------------------------------------------
    # Compare to reference if available
    # ----------------------------------------------------------------
    try:
        ref = np.load(ref_npy).astype(np.uint8)
    except FileNotFoundError:
        print(f"Reference file {ref_npy} not found — skipping comparison")
        return

    if ref.shape != (ROWS, COLS):
        print(f"WARNING: reference shape {ref.shape} does not match expected ({ROWS}, {COLS})")
        return

    errors      = int(np.sum(output_pixels != ref))
    total       = ROWS * COLS
    error_pct   = 100.0 * errors / total

    print()
    print(f"  Total pixels : {total}")
    print(f"  Matching     : {total - errors}")
    print(f"  Errors       : {errors}  ({error_pct:.2f}%)")

    if errors == 0:
        print("\n  PASS — simulator output matches reference exactly.")
    else:
        print(f"\n  FAIL — {errors} pixel(s) differ.")
        if pil_ok:
            diff = np.abs(output_pixels.astype(np.int16) - ref.astype(np.int16)).astype(np.uint8)
            Image.fromarray((diff * 17).astype(np.uint8)).save("diff.png")
            print("  Diff image written to diff.png")

        # Print a small sample of mismatches for quick debugging
        ys, xs = np.where(output_pixels != ref)
        print(f"\n  First up to 10 mismatches (row, col): got → expected")
        for i in range(min(10, len(ys))):
            r, c = int(ys[i]), int(xs[i])
            print(f"    ({r:3d}, {c:3d}): {output_pixels[r,c]:2d} → {ref[r,c]:2d}")


if __name__ == "__main__":
    main()
