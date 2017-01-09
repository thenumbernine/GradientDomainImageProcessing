#! /usr/bin/env luajit
local Image = require 'image'

local image = Image'source.png':setFormat'double'

local size = 20
local sigma = size/3
local blurKernelX = Image.gaussianKernel(sigma, 2*size+1, 1)
local blurKernelY = blurKernelX:transpose()
local function blurOp(image)
	return image
		:kernel(blurKernelX, true, -size, 0)
		:kernel(blurKernelY, true, 0, -size)
	--return image:simpleBlur()
end

local blur = blurOp(image)

blur:save'lua-blurred.png'

-- now perform the inverse operation ...
-- i.e. if the kernel was a linear filter applied to the image: A x = b
-- solve the linear problem: x = A^-1 b
--[[
blur:solveConjugateGradient{
	A = blurOp,
	--x0 = blur,		-- cheat: use the original as the initial guess
	maxiter = 100,--blur.width * blur.height * blur.channels,
	epsilon = 1e-15,
}:save'lua-blurred-unblurred-cg.png'
--]]
--[[
blur:solveConjugateResidual{
	A = blurOp,
	--x0 = blur,		-- cheat: use the original as the initial guess
	maxiter = 100,--blur.width * blur.height * blur.channels,
	epsilon = 1e-15,
}:save'lua-blurred-unblurred-cr.png'
--]]
-- [[	lua not enough memory.  probably because i'm using lua arrays for the 2d arrays instead of something more dense
blur:solveGMRes{
	A = blurOp,
	--x0 = blur,		-- cheat: use the original as the initial guess
	maxiter = blur.width * blur.height * blur.channels,
	restart = 10,
	epsilon = 1e-10,
}:save'lua-blurred-unblurred-gmres.png'
--]]
