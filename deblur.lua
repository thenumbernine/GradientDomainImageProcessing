#! /usr/bin/env luajit
local Image = require 'image'

--local size = 20	-- 20 is crashing ... out of memory or something?
local size = 2
local sigma = size/3
local blurKernelX = Image.gaussianKernel(sigma, 2*size+1, 1)
local blurKernelY = blurKernelX:transpose()

local function blurOp(image)
	--[[ trying with gaussian blur filter
	return image
		:kernel(blurKernelX, true, -size, 0)
		:kernel(blurKernelY, true, 0, -size)
	--]]
	-- [[ using something simple like a 3x3 kernel
	return image:simpleBlur()
	--]]
end

local fn = ...

local blur
if not fn then
-- [[ use canned blurred image
	local image = Image'source.png':setFormat'double'
	blur = blurOp(image)
	blur:save'lua-blurred.png'
--]]
else
-- [[ use cmdline
	blur = Image(fn):setFormat'float'
--]]
end
print('deblurring image size', blur.width, blur.height)

-- now perform the inverse operation ...
-- i.e. if the kernel was a linear filter applied to the image: A x = b
-- solve the linear problem: x = A^-1 b
--[[
blur:solveConjGrad{
	A = blurOp,
	--x = blur,		-- cheat: use the original as the initial guess
	maxiter = 100,--blur.width * blur.height * blur.channels,
	epsilon = 1e-15,
	errorCallback = function(err, iter)
		io.stderr:write(iter,'\t',err,'\n')
	end,
}:save'lua-blurred-unblurred-cg.png'
--]]
--[[
blur:solveConjRes{
	A = blurOp,
	--x = blur,		-- cheat: use the original as the initial guess
	maxiter = 100,--blur.width * blur.height * blur.channels,
	epsilon = 1e-15,
	errorCallback = function(err, iter)
		io.stderr:write(iter,'\t',err,'\n')
	end,
}:save'lua-blurred-unblurred-cr.png'
--]]
--[[	lua not enough memory.  probably because i'm using lua arrays for the 2d arrays instead of something more dense
blur:solveGMRes{
	A = blurOp,
	--x = blur,		-- cheat: use the original as the initial guess
	maxiter = blur.width * blur.height * blur.channels,
	restart = 10,
	epsilon = 1e-10,
	errorCallback = function(err, iter)
		io.stderr:write(iter,'\t',err,'\n')
	end,
}:save'lua-blurred-unblurred-gmres.png'
--]]
-- [=[ solve conjgrad on the gpu
local env = require 'cl.obj.env'{
	precision = 'double',
	-- don't bother with rgb dense structures, just make the size 3x wider
	size = {3*blur.width, blur.height},
}
blur = blur:rgb():setFormat(env.real)
local bufferGPU = env:buffer{type='real', data=blur.buffer}
local restoreGPU = env:buffer{data=blur.buffer}
require 'solver.cl.gmres'{
	env = env,
	x = restoreGPU,
	b = bufferGPU,
	A = env:kernel{
		argsOut = {{name='y', type='real', obj=true}},
		argsIn = {{name='x', type='real', obj=true}},
		body = require 'template'[[
	if (i.x <= 2 || i.x >= size.x-3 ||
		i.y == 0 || i.y == size.y-1
	) {
		y[index] = x[index];
	} else {
		y[index] = (
#if 0 //why not working?
			  x[index - 3 - stepsize.y]
			+ x[index + 3 - stepsize.y]
			+ x[index - 3 + stepsize.y]
			+ x[index + 3 + stepsize.y]
#else	//this works but on even width images it gets red-black errors
			  4. * x[index]
#endif
			+ 2. * x[index - 3]
			+ 2. * x[index + 3]
			+ 2. * x[index - stepsize.y]
			+ 2. * x[index + stepsize.y]
			+ 4. * x[index]
		) * (real).0625;
	}
]],
	},
	maxiter = 300,
	epsilon = 1e-15,
	errorCallback = function(err, iter)
		print(iter, err)
	end,
}()
local ffi = require 'ffi'
ffi.copy(blur.buffer, restoreGPU:toCPU(), env.base.volume * ffi.sizeof(env.real))
blur:save'lua-blurred-unblurred-cr-gpu.png'
--]=]

