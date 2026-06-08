import numpy as np
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# All test images go to verification/test_images/
# backend_top_tests/test_top.py    loads from ../test_images/
# full_system_tests/test_full_system.py loads from ../test_images/

out_dir = os.path.join(SCRIPT_DIR, "test_images")
os.makedirs(out_dir, exist_ok=True)

# gradient: 0 (black) -> 15 (white), row by row
img2_gradient = np.array([
    [ 0,  1,  2,  3],
    [ 4,  5,  6,  7],
    [ 8,  9, 10, 11],
    [12, 13, 14, 15],
], dtype=np.uint8)
np.save(os.path.join(out_dir, "img2_gradient.npy"), img2_gradient)

# center square: bright center, dark background
img3_center_square = np.array([
    [ 0,  0,  0,  0],
    [ 0, 12, 12,  0],
    [ 0, 12, 12,  0],
    [ 0,  0,  0,  0],
], dtype=np.uint8)
np.save(os.path.join(out_dir, "img3_center_square.npy"), img3_center_square)

# all ones: every pixel at max brightness
img_all_ones = np.full((4, 4), 15, dtype=np.uint8)
np.save(os.path.join(out_dir, "img_all_ones.npy"), img_all_ones)

# checkerboard: alternating 0 / 15
img1_checkerboard = np.array([
    [ 0, 15,  0, 15],
    [15,  0, 15,  0],
    [ 0, 15,  0, 15],
    [15,  0, 15,  0],
], dtype=np.uint8)
np.save(os.path.join(out_dir, "img1_checkerboard.npy"), img1_checkerboard)

# 30x30 diagonal gradient: pixel = (row + col) * 15 // 58, covers full 0-15 range
_r, _c = np.mgrid[0:30, 0:30]
img_30x30_gradient = ((_r + _c) * 15 // 58).astype(np.uint8)
np.save(os.path.join(out_dir, "img_30x30_gradient.npy"), img_30x30_gradient)

print("Test images written to:", out_dir)
for name, arr in [("img2_gradient", img2_gradient),
                  ("img3_center_square", img3_center_square),
                  ("img_all_ones", img_all_ones),
                  ("img1_checkerboard", img1_checkerboard),
                  ("img_30x30_gradient", img_30x30_gradient)]:
    print(f"  {name} {arr.shape}:\n{arr}")
