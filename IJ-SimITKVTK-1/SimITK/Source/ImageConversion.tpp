/******************************************************************************
SIMITK Project

Copyright (c) Queen's University
All rights reserved.

See Copyright.txt for more details.

Karen Li and Jing Xiang
June 2008

ImageConversion.tpp - Contains functions that manipulate pointers to the 
image data which result in forcing ITK to use memory that has already been
allocated by MATLAB.
******************************************************************************/

#include "ImageConversion.h" 

template<class PixelType, class ImageType>
void ConvertMatrixToImage(PixelType* matrix, ImageType* image, unsigned int* sizeImage)
{
	// Sets the region.
	typename ImageType::RegionType inputRegion;
	typename ImageType::RegionType::IndexType inputStart;
	typename ImageType::RegionType::SizeType size;
	
	int imageDimension = ImageType::GetImageDimension();
	unsigned long numPixels = 1;
	for (int dimension = 0; dimension < imageDimension; dimension++){
		inputStart[dimension] = 0;
		size[dimension] = sizeImage[dimension];
		numPixels *=sizeImage[dimension];
	}
	inputRegion.SetSize(size);
	inputRegion.SetIndex(inputStart);
	image->SetRegions(inputRegion);
	
	//sets the pointer of the container to the image data
	image->GetPixelContainer()->SetImportPointer(matrix, numPixels, false);
}

template<class PixelType, class ImageType>
void ConvertImageToMatrix(ImageType* image, PixelType* matrix, unsigned int* sizeImage)
{

	int imageDimension = ImageType::GetImageDimension();
	unsigned long numPixels = 1;
	for (int dimension = 0; dimension < imageDimension; dimension++){
		numPixels *=sizeImage[dimension];
	}
	image->GetPixelContainer()->SetImportPointer(matrix,numPixels,false);
}

template<class PixelType, class ImageType>
void ConvertImageToMatrix(const ImageType* image, const PixelType* matrix, unsigned int* sizeImage)
{

	int imageDimension = ImageType::GetImageDimension();
	unsigned long numPixels = 1;
	for (int dimension = 0; dimension < imageDimension; dimension++){
		numPixels *=sizeImage[dimension];
	}
	image->GetPixelContainer()->SetImportPointer(matrix,numPixels,false);
}

/*
 * Overloaded version of ConvertImageToMatrix() for use in the ImageToImageRegistrationHelper filter 
 * block. When ImageToImageRegistrationHelper is used, it allocates new memory for the output image and
 * thus cannot be forced to use memory allocated by MATLAB.
 */
template<class PixelType, class ImageType>
void ConvertImageToMatrix(const ImageType* image, PixelType* matrix){

	// Prepares the iterator that will run through the image.
	itk::ImageRegionConstIteratorWithIndex<ImageType> 
				It( image, image->GetRequestedRegion() );

	typename ImageType::IndexType requestedIndex =
	            image->GetRequestedRegion().GetIndex();
	typename ImageType::SizeType requestedSize =
	            image->GetRequestedRegion().GetSize();
	
	// This integer will be used as the index for the matrix when transferring
	// the image.
	int index=0;
	
	// The following loop goes through the image and transfer the value of 
	// the pixels to a matrix.
	for ( It.GoToBegin(); !It.IsAtEnd(); ++It){
		// Gets the index of the iterator.
		typename ImageType::IndexType idx = It.GetIndex();
		// Stores temporarily the value of the pixel at the iterator index.
		PixelType temp=image->GetPixel(idx);
		// Transfers the image information to the array.
		matrix[index]=(PixelType) temp;		
		index++; //increments index
	}
}
