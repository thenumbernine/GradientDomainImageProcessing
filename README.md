Image Processing

uses:
https://github.com/thenumbernine/lua-image

deblur.lua = runs the inverse of a guassian blur filter

gradientDomain.lua = runs a graidnet-domain image processing example by pasting the gradient of one portion of an image onto another portion, then reconstructing the image from the new gradient's divergence

examples:

original:
![](https://cdn.rawgit.com/thenumbernine/ImageProcessing/master/source.png)

blurred with Lua:
![](https://cdn.rawgit.com/thenumbernine/ImageProcessing/master/lua-blurred.png)

unblurred using a conjugate-gradient iterative solver:
![](https://cdn.rawgit.com/thenumbernine/ImageProcessing/master/lua-blurred-unblurred-cg.png)

blurred with Matlab:
![](https://cdn.rawgit.com/thenumbernine/ImageProcessing/master/matlab-blurred.png)

unblurred with Matlab:
![](https://cdn.rawgit.com/thenumbernine/ImageProcessing/master/matlab-blurred-unblurred.png)

gradient-domain copy-and-paste in Lua:
![](https://cdn.rawgit.com/thenumbernine/ImageProcessing/master/modified-restored.png)
