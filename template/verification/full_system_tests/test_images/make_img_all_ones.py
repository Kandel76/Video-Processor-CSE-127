import numpy as np
#import matplotlib.pyplot as plt

#all ones (max value) test pattern
img5 = np.full((4, 4), 15, dtype=np.uint8)

#save img as .npy
np.save("img_all_ones.npy", img5)

#print(img5)

#visualize image
#plt.imshow(img5, cmap="gray", vmin=0, vmax=15)
#plt.title("All Ones (White)")
#plt.show()
