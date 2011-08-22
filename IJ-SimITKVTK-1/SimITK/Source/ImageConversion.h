/******************************************************************************
SIMITK Project

Copyright (c) Queen's University
All rights reserved.

See Copyright.txt for more details.

Karen Li and Jing Xiang
June 2008

ImageConversion.h

ImageConversion.tpp - Contains functions that manipulate pointers to the 
image data which result in forcing ITK to use memory that has already been
allocated by MATLAB.
******************************************************************************/

#include "itkImage.h"
#include "itkRGBPixel.h"
#include "itkImageRegionConstIteratorWithIndex.h"
#include "itkImageRegionIteratorWithIndex.h"
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"
#include "itkRescaleIntensityImageFilter.h"
#include "itkCastImageFilter.h"
#include "itkResampleImageFilter.h"
#include "itkLinearInterpolateImageFunction.h"
#include <fstream>
#include <iostream>

// Image-matrix converters.
template<class PixelType, class ImageType>
void ConvertMatrixToImage(PixelType* matrix, ImageType* image, unsigned int* sizeImage);

template<class PixelType, class ImageType>
void ConvertImageToMatrix(ImageType* image, PixelType* matrix, unsigned int* sizeImage);

template<class PixelType, class ImageType>
void ConvertImageToMatrix(const ImageType* image, PixelType* matrix);

