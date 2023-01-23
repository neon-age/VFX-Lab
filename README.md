# VFX-Lab
 Shaders and VFX experimentation in URP and BIRP

### Shadow map blur
Directly inside surface shader, uses simple spiral blur (noise-based sampling) and takes light depth-map (lower-res mip) as distance.\
Noisy and glitchy, could use a better blurring algorithm for both depth map and shadows.
![image](https://user-images.githubusercontent.com/29812914/213963768-f38346a0-dadb-4dd7-9017-d1bc39e4063d.png)
