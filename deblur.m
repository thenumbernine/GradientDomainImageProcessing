% load source image
rgbImage = double(imread('source.png'));

% get its size
[imageHeight, imageWidth, imageChannels] = size(rgbImage)

% get the size (in pixels) of each individual channel
n = imageHeight * imageWidth;

disp('creating sparse blur matrix...');
% create sparse blur matrix
sparseMatrixSize = 5 * (imageWidth-2) * (imageHeight-2);
blurIs = zeros(sparseMatrixSize,1);
blurJs = zeros(sparseMatrixSize,1);
blurVs = zeros(sparseMatrixSize,1);
blurOffset = 1;
for j=1:imageWidth
	for i=1:imageHeight
		k = i + imageHeight * (j-1);
		if i>1 && i<imageHeight && j>1 && j<imageWidth
		% non-boundary cells
			blurIs(0+blurOffset) = k;
			blurJs(0+blurOffset) = k;
			blurVs(0+blurOffset) = 4/8;
			
			blurIs(1+blurOffset) = k;
			blurJs(1+blurOffset) = k+1;
			blurVs(1+blurOffset) = 1/8;
			
			blurIs(2+blurOffset) = k;
			blurJs(2+blurOffset) = k-1;
			blurVs(2+blurOffset) = 1/8;
			
			blurIs(3+blurOffset) = k;
			blurJs(3+blurOffset) = k+imageHeight;
			blurVs(3+blurOffset) = 1/8;
			
			blurIs(4+blurOffset) = k;
			blurJs(4+blurOffset) = k-imageHeight;
			blurVs(4+blurOffset) = 1/8;
		
			blurOffset = blurOffset + 5;
		else
		% boundary cells:
			
		end
	end
end
if blurOffset ~= sparseMatrixSize+1
	disp(strcat('expected blurOffset ',num2str(blurOffset),' to match sparseMatrixSize ',num2str(sparseMatrixSize)));
	error('here')
end
blur = sparse(blurIs, blurJs, blurVs, n, n);
disp('done creating sparse blur matrix');

% create dest of un-blurred image
rgbBlurredImage = zeros(imageHeight, imageWidth, imageChannels);
rgbUnblurredImage = zeros(imageHeight, imageWidth, imageChannels);

% cycle through all channels ...
disp('blurring and unblurring images...');
for channel=1:imageChannels
	% pick out each layer separately
	image = rgbImage(:,:,channel);

	% unravel it into a single vector
	image = reshape(image, n, 1);

	% apply blur filter
	blurredChannel = blur * image;

	% try to undo the blur filter
	unblurredImage = blur \ blurredChannel;

	% re-ravel it back into an image, and re-add the channel back into the original image
	rgbBlurredImage(:,:,channel) = reshape(blurredChannel, imageHeight, imageWidth);

	% re-ravel and re-add to unblurred image
	rgbUnblurredImage(:,:,channel) = reshape(unblurredImage, imageHeight, imageWidth);
end
disp('done blurring and unblurring images');

% write out the blurred image
imwrite(uint8(rgbBlurredImage), 'matlab-blurred.png');

% write out the blurred-then-unblurred image
imwrite(uint8(rgbUnblurredImage), 'matlab-blurred-unblurred.png');

% calculate the average error per pixel between the original and the blurred-then-unblurred images
function y = imageDistance(a,b)
	n = prod(size(a));
	y = norm(reshape(a-b, n, 1),'fro') ./ n;
end;

disp('source to blurred error:');
imageDistance(rgbImage, rgbBlurredImage)
disp('blurred to unblurred error:');
imageDistance(rgbBlurredImage, rgbUnblurredImage)
disp('source to unblurred error:');
imageDistance(rgbImage, rgbUnblurredImage)
