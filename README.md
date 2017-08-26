# NNAO
Neural Network Ambien Occlusion based on http://theorangeduck.com/page/neural-network-ambient-occlusion for Unity.

# Features
* Bilateral Bluring (with normal and depth tresholds)
* Temporal Smoothing
* Downsampling and Bilateral upsampling

This implimitation writes to the GBuffer using CommandBuffers so that an Ambien only mode is achieved.
Project includes Unity's Legacy Cinematic Effects and [MiniAO](https://github.com/keijiro/MiniEngineAO) for comparison.

# Requirements
* Unity 2017.1.0f3 and up
* DirectX 11

# Screenshots
With NNAO:
![](https://github.com/simeonradivoev/NNAO/raw/master/Screenshots/Screenshot-08-26-17-20-23-05.png)
Without NNAO:
![](https://github.com/simeonradivoev/NNAO/raw/master/Screenshots/Screenshot-08-26-17-20-42-25.png)
NNAO Only:
![](https://github.com/simeonradivoev/NNAO/raw/master/Screenshots/Screenshot-08-26-17-20-23-10.png)
With NNAO:
![](https://github.com/simeonradivoev/NNAO/raw/master/Screenshots/Screenshot-08-26-17-20-23-26.png)
Without NNAO:
![](https://github.com/simeonradivoev/NNAO/raw/master/Screenshots/Screenshot-08-26-17-20-42-36.png)
NNAO Only:
![](https://github.com/simeonradivoev/NNAO/raw/master/Screenshots/Screenshot-08-26-17-20-23-29.png)
