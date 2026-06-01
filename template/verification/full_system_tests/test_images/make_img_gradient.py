import numpy as np
#import matplotlib.pyplot as plt

#gradient test pattern (0 black -> 15 white)
img2 = np.array([
    [0, 1, 2, 3],
    [4, 5, 6, 7],
    [8, 9, 10, 11],
    [12, 13, 14, 15]
], dtype=np.uint8)

#save img as .npy for testing
np.save('img2_gradient.npy', img2)

#print(img2)

#visualize image
#plt.imshow(img2, cmap="gray", vmin=0, vmax=15)
#plt.title("gradient")
#plt.show()
