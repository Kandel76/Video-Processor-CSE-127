import numpy as np
#import matplotlib.pyplot as plt

#all zeros test pattern
img4 = np.zeros((4,4), dtype=np.uint8)

#save img as .npy
np.save("img_all_zeros.npy", img4)

#print(img4)

#visualize image
#plt.imshow(img4, cmap="gray", vmin=0, vmax=15)
#plt.title("All Zeros (Black)")
#plt.show()
