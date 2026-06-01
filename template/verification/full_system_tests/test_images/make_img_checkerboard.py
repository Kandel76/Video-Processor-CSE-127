import numpy as np
#import matplotlib.pyplot as plt

# 0 = black, 15 = white
img1 = np.array([
    [0, 15, 0, 15],
    [15, 0, 15, 0],
    [0, 15, 0, 15],
    [15, 0, 15, 0]
], dtype=np.uint8)

#save image as .npy for use in testbenches
np.save('img1_checkerboard.npy', img1)
#print(img1)

#visualize image
#plt.imshow(img1, cmap="gray", vmin=0, vmax=15)
#plt.title("checkerboard")
#plt.show()
