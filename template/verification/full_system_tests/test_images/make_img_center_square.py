import numpy as np
#import matplotlib.pyplot as plt

# bright region in center, dark background
img3 = np.array([
    [0, 0, 0, 0],
    [0, 12, 12, 0],
    [0, 12, 12, 0],
    [0, 0, 0, 0],
], dtype=np.uint8)

#save img as .npy
np.save('img3_center_square.npy', img3)
#print(img3)

#visualize image
#plt.imshow(img3, cmap="gray", vmin=0, vmax=15)
#plt.title("center square")
#plt.show()


