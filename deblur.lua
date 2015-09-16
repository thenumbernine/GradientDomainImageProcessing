#! /usr/bin/env luajit
local Image = require 'image'

local image = Image'source.png':setFormat'double'

local size = 20
local sigma = size/3
local blurKernelX = Image.gaussianKernel(sigma, 2*size+1, 1):normalize()
local blurKernelY = blurKernelX:transpose():normalize()
local function blurOp(image)
	return image
		:kernel(blurKernelX, false, -size, 0)
		:kernel(blurKernelY, false, 0, -size)
	--return image:simpleBlur()
end

local blur = blurOp(image)

blur:save'lua-blurred.png'

-- now perform the inverse operation ...
-- i.e. if the kernel was a linear filter applied to the image: A x = b
-- solve the linear problem: x = A^-1 b
local deblur = blur:solveConjugateResidual{
	A = blurOp,
	--x0 = blur,		-- cheat: use the original as the initial guess
	maxiter = 100,
	epsilon = 1e-5,
}

deblur:save'lua-blurred-unblurred.png'

