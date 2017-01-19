#! /usr/bin/env luajit

--[[
gradient domain image processing ...
1) calc gradient of source and dest images
2) paste gradients
3) calc divergence
4) inverse laplacian (with boundary conditions around pasted region)
--]]

local Image = require 'image'

local image = Image'source.png':setFormat'double':rgb()

local extendedBorder = 1
--[[
local copyArgs = {x=490, y=100, width=400, height=200}
local pasteArgs = {x=337, y=271}
--]]
-- [[
local copyArgs = {x=63, y=86, width=238-63, height=251-86}
local pasteArgs = {x=435, y=66}
--]]

-- take gradient of whole image (technically all we need is the extended image segment)
local imageGradX, imageGradY = image:gradient'simple'
-- take gradient of the copied region
local copyGradX = imageGradX:copy(copyArgs)
local copyGradY = imageGradY:copy(copyArgs)

-- paste the copied region somewhere else ...
local imageGradX = imageGradX:paste{image=copyGradX, x=pasteArgs.x, y=pasteArgs.y}
imageGradX:normalize():rgb():save'modified-gradient-x.png'
local imageGradY = imageGradY:paste{image=copyGradY, x=pasteArgs.x, y=pasteArgs.y}
imageGradY:normalize():rgb():save'modified-gradient-y.png'

-- TODO offset one of these ...
local imageGradXX = imageGradX:gradient('simple', 1)
local _, imageGradYY = imageGradY:gradient('simple', 1)

local imageDiv = imageGradXX + imageGradYY
imageDiv:normalize():rgb():save'modified-divergence.png'

-- take the divergence and extend it one past the borders
local extendedCopyArgs = {
	x = copyArgs.x - extendedBorder,
	y = copyArgs.y - extendedBorder,
	width = copyArgs.width + 2 * extendedBorder,
	height = copyArgs.height + 2 * extendedBorder,
}
local extendedPasteArgs = {
	x = pasteArgs.x - extendedBorder,
	y = pasteArgs.y - extendedBorder,
	width = copyArgs.width + 2 * extendedBorder,
	height = copyArgs.height + 2 * extendedBorder,
}

-- use the boundary in the region extended around the destination 
-- for the boundary conditions of the linear system
-- to ensure the pasted image flows into the background of the source image
local imagePasteCroppedExt = image:copy(extendedPasteArgs)

-- source region - used as an initial guess to the solution vector (which is the final image)
local imageDivCopyCroppedExt = imageDiv:copy(extendedCopyArgs)
	-- incorporate boundaries in the divergence (which will be inverse-solved to find the original image)
	-- in the boundary regions use an identity kernel rather than a divergence kernel
	:paste{x=0, y=0, image=imagePasteCroppedExt:copy{x=0,y=0,width=imagePasteCroppedExt.width,height=extendedBorder}}
	:paste{x=0, y=imagePasteCroppedExt.height-extendedBorder, image=imagePasteCroppedExt:copy{x=0,y=imagePasteCroppedExt.height-extendedBorder,width=imagePasteCroppedExt.width,height=extendedBorder}}
	:paste{x=0, y=0, image=imagePasteCroppedExt:copy{x=0,y=0,width=extendedBorder,height=imagePasteCroppedExt.height}}
	:paste{x=imagePasteCroppedExt.width-extendedBorder, y=0, image=imagePasteCroppedExt:copy{x=imagePasteCroppedExt.width-extendedBorder,y=0,width=extendedBorder,height=imagePasteCroppedExt.height}}

-- use the destination region as an initial guess
local restoredCroppedInitialGuess = image:copy(extendedPasteArgs)	--extendedCopyArgs)
-- [[ add noise through the non-boundary region ... convergence is much slower, but results look better (in the one case I tested)
restoredCroppedInitialGuess = restoredCroppedInitialGuess:paste{
	x = 1, y = 1,
	image = Image(restoredCroppedInitialGuess.width-2, restoredCroppedInitialGuess.height-2, restoredCroppedInitialGuess.channels, restoredCroppedInitialGuess.format, function(x,y)
		return 2*math.random()-1
	end)}
--]]

--[[ solve conjgrad on the cpu
-- 'self' is the initial guess, A is the operator ...
local restoredCropped = imageDivCopyCroppedExt:solveConjGrad{
	x = restoredCroppedInitialGuess,
	-- the linear operator to invert is the discrete laplacian (divergence) ...
	A = function(image)
		return image:divergence()
		-- ... with identity linear function for boundary elements
			:paste{x=0, y=0, image=image:copy{x=0,y=0,width=image.width,height=extendedBorder}}
			:paste{x=0, y=image.height-extendedBorder, image=image:copy{x=0,y=image.height-extendedBorder,width=image.width,height=extendedBorder}}
			:paste{x=0, y=0, image=image:copy{x=0,y=0,width=extendedBorder,height=image.height}}
			:paste{x=image.width-extendedBorder, y=0, image=image:copy{x=image.width-extendedBorder,y=0,width=extendedBorder,height=image.height}}
	end,
	maxiter = imageDivCopyCroppedExt.width * imageDivCopyCroppedExt.height * imageDivCopyCroppedExt.channels,
	epsilon = 1e-15,
	errorCallback = function(err, iter)
		io.stderr:write(iter,'\t',err,'\n')
	end,
}
--]]
-- [=[ solve conjgrad on the gpu
local env = require 'cl.obj.env'{
	size = {imageDivCopyCroppedExt.width, imageDivCopyCroppedExt.height},
}
local bufferCPU = imageDivCopyCroppedExt:setFormat(env.real)
local _3xwidth = env:domain{size={env.base.size.x*3, env.base.size.y}}	-- don't bother with rgb dense structures, just make the size 3x wider
local imageDivCopyCroppedExtGPU = _3xwidth:buffer{type='real', data=bufferCPU.buffer}
local restoreCroppedGPU = _3xwidth:buffer{data=bufferCPU.buffer}
print('cropped size',imageDivCopyCroppedExt.width, imageDivCopyCroppedExt.height)
require 'solver.cl.conjgrad'{
	env = env,
	size = _3xwidth.volume,	-- used for vector operations 
	x = restoreCroppedGPU,
	b = imageDivCopyCroppedExtGPU,
	A = env:kernel{
		argsOut = {{name='y', type='real', obj=true}},
		argsIn = {{name='x', type='real', obj=true}},
		body = require 'template'[[
	if (i.x == 0 || i.x == size.x-1 ||
		i.y == 0 || i.y == size.y-1) {
		<? for j=0,2 do ?>
			y[<?=j?>+3*index] = x[<?=j?>+3*index];
		<? end ?>
	} else {
		<? for j=0,2 do ?>
		y[<?=j?>+3*index] = x[<?=j?>+3*(index - stepsize.x)]
			+ x[<?=j?>+3*(index + stepsize.x)]
			+ x[<?=j?>+3*(index - stepsize.y)]
			+ x[<?=j?>+3*(index + stepsize.y)]
			- 4 * x[<?=j?>+3*index];
		<? end ?>
	}
]],
	},
	epsilon = 1e-15,
	errorCallback = function(err, iter)
		print(iter, err)
	end,
}()
local restoredCropped = imageDivCopyCroppedExt:clone()
restoredCropped:setFormat(env.real)
local ffi = require 'ffi'
ffi.copy(restoredCropped.buffer, restoreCroppedGPU:toCPU(), 3 * env.base.volume * ffi.sizeof(env.real))
restoredCropped:setFormat'double'
--]=]
local restored = image:paste{x=extendedPasteArgs.x, y=extendedPasteArgs.y, image=restoredCropped}
restored:save'modified-restored.png'
