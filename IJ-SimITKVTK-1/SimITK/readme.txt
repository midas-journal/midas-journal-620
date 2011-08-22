SIMITK Project

Karen Li and Jing Xiang
June 2008

==================
BUILDING SIMITK
==================

If you are using Windows, then you can go directly to the Bin directory,
which has copies of all the files that you need to use SimITK with
MATLAB 2007a, 2007b, or 2008a if you already have Simulink installed
for your version of MATLAB.  If you need to build SimITK, then follow
the instructions below.

Before building SimITK, you must first ensure that ITK, MATLAB, Perl and 
CMake have been installed. We have successfully built and tested SimITK using 
ITK 3.6, MATLAB 2007a, Perl 5.10.0 and CMake 2.6.


Building on Windows
-------------------

SimITK has been tested on Windows using Microsoft Visual Studio 2005 as the 
compiler.  Because SimITK uses Simulink, you should have a Simulink license,
and you must have Simulink installed with your copy of Matlab.


  1. Run CMakeSetup.exe. Specify the proper SimITK source folder and the 
     folder where the binaries should be built in the appropriate fields
     at the top of the graphical window. Press Configure and ensure the
     Cache Values window correctly specifies all library paths. It is
     important to note that different versions of MATLAB may have different 
     directory structures and thus these paths may need to be modified
     depending on the version number. If the paths are updated, Configure 
     must be pressed again.

  2. Once configuring is done, press OK.  A .sln file will be created by
     CMake in the binary folder. Open this file in Visual Studio and
     compile the project.

  3. The SimITK .mdl Library files will be found in the same binary folder
     as the .sln file. The SimITK .dll files will be created in a
     subdirectory of the binary folder, either in Debug or Release
     depending on which mode was used for compiling. The .mdl and .dll
     files must be moved to the same folder. SimITK can now be used from
     this folder.


Building on Linux
-------------------

  Because SimITK uses Simulink, you should have a Simulink license,
  and you must have Simulink installed with your copy of Matlab.

  In order to build SimITK on Linux, you must use a compiler that is
  compatible with MATLAB.  For Matlab 7.4 (2007a) and 7.6 (2008a), the
  supported compiler is gcc-3.2, but we have also found that gcc-3.4
  and gcc-4.0 work, while gcc-4.2 does not work.

  The copy of ITK that you use should be built with the same compiler.


  1. Make a new directory called "Build".  From inside this directory,
     execute:

     ccmake <full_path_to_source_dir>

     Press "c" to configure.  The first time around, it will complain
     about missing files.  Press "e" to hide the errors and go back to
     the main cmake screen.
        
  2. Set MATLAB_ROOT to the directory where Matlab is installed, e.g. 
     /usr/local/matlab74, and press "c" again.  If it still complains
     about missing Matlab libraries, press "t" to go to the advanced
     view and manually enter the locations of the Matlab libraries
     and header file directories.

  3. Set the ITK_DIR to your ITK binary directory and press "c" again.
     Also set the CMAKE_BUILD_TYPE to the same build type that you
     used for ITK, e.g. CMAKE_BUILD_TYPE=Release.

  4. Press "g" to generate the make files for SimITK.  When cmake exits,
     type "make" to build SimITK.

  5. The binary directory will now contain SimITK .mdl Library files as
     well as SimITK .mexglx (Linux 32-bit) or .mexa64 (Linux 64-bit) files.
     SimITK can be used from this directory.


==================
EXAMPLES
==================

For all of the example models provided, ensure the .mdl model file is in the 
same directory as the SimITK .dll files and .mdl Library files, and then open 
the model in MATLAB. Clicking on the individual SimITK blocks in the model 
shows the parameter values of the blocks.

The simulation settings of all models are set so that the models do not run 
continuously. These settings can be found by going to the 'Simulation' menu 
and selecting 'Configuration Parameters'. Note that both the start and stop 
simulation time are set to 0, the solver type is fixed-step and the solver is 
discrete.

When the models are run, the output image is created in the current 
directory.


CannyEdgeDetectionFL2Model.mdl
------------------------------

This model identifies the edges of an image by applying the 
itk::CannyEdgeDetectionImageFilter. The input image is a 2-dimensional 
computed tomography of the head and is taken from the ITK example data. The 
parameters of the blocks in this model are set as follows:

itkReaderFL2
    FileName             'cthead1.png'

itkCannyEdgeDetectionImageFilterFL2
    LowerThreshold       10
    MaximumError         [0.01 0.01]
    OutsideValue         0
    UpperThreshold       30
    Variance             [0.1 0.1]

itkWriterFL2
    FileName             'outputCannyEdgeDetectionFL2Model.mhd'


ConfidenceConnectedFL2Model.mdl
-------------------------------

This model performs region growing segmentation using the 
itk::ConfidenceConnectedImageFilter. Before the ITK filter is executed, 
Gaussian smoothing is done using a MATLAB function. Thus, this pipeline 
demonstrates the combining of both MATLAB and ITK functionality. The input 
used is an MRI of the brain, taken from the ITK example data, and the output 
shows a white matter segmentation.

The parameters of the blocks in this model are set as follows:

itkReaderFL2
    FileName             'BrainProtonDensitySlice.png'

gaussian
    M-file name          mlgaussian
    Parameters           3

itkConfidenceConnectedImageFilterFL2
    InitialNeighborhoodRadius 3
    Multiplier           2.5
    NumberOfIterations   5
    ReplaceValue         255
    Seed                 [128 116]
    
itkWriterFL2
    FileName             'outputConfidenceConnectedFL2Model.mhd'


ImageToImageRegistrationHelperUC2Model.mdl
------------------------------------------

This model demonstrates image registration using the 
ImageToImageRegistrationHelper block. An MRI of the brain was rotated and 
then registered back to itself using rigid registration with ITK's mean 
squares metric. The parameters of the blocks in this model are set as 
follows:

itkReaderUC2
    FileName             'BrainProtonDensitySliceBorder20.png'

itkReaderUC1
    FileName             'BrainProtonDensitySliceRotate.png'

itkImageToImageRegistrationHelperUC2
    InitialMethodEnum    2
    EnableAffineRegistration 0
    EnableBSplineRegistration 0
    EnableInitialRegistration 1
    EnableRigidRegistration 1
    RigidMaxIterations 500
    RigidSamplingRatio 0.05
    RigidTargetError   0.1
    RigidInterpolationMethodEnum 0
    RigidMetricMethodEnum 2
    RigidOptimizationMethodEnum 1
    [all remaining Affine and BSpline parameters can be set to 0]

itkWriterUC2
    FileName             'outputImageToImageRegistrationHelperUC2Model.png'


ResampleUC2Model.mdl
--------------------

This model applies the itk::ResampleImageFilter to a 2-dimensional image. In 
addition to the image, this filter expects a transform and an interpolator as 
inputs. The transform is used to map the input image to an output image, and 
the interpolator is used to generate image intensities at non-grid positions.

Interpolators are represented in SimITK as special blocks with no parameters. 
In this case, the LinearInterpolateImageFunctionUC2 block is used and 
connected to the special third input of the ResampleImageFilter block.

Transforms are also represented in SimITK as special blocks. Unlike the other
filters and special blocks, transforms are not specific to pixeltype. 
Therefore, they are automatically generated separately from the other filters 
into the libraries SimITKTransformLibrary2D.mdl and 
SimITKTransformLibrary3D.mdl, distinguished only by dimensionality. All 
transforms take two arrays as parameters, Parameters and FixedParameters. The 
size and content of these arrays will vary according to transform. In this 
sample model, the TranslationTransform2D block is used to specify a 
translation of 25 along both the X and Y axes. The transform block is 
connected to the special fourth input of the ResampleImageFilter block.

The parameters of the blocks in this model are set as follows:

itkReaderUC2
    FileName             'cthead1.png'

itkTranslationTransform2D
    Parameters           [25 25]
    FixedParameters      []

itkResampleImageFilterUC2
    DefaultPixelValue    0
    OutputOrigin         [0 0]
    OutputSpacing        [1 1]
    Size                 [256 256]

itWriterUC2
    FileName             'outputResampleUC2Model.png'


FastMarchingFL3Model.mdl
------------------------

The FastMarchingFL3Model links several SimITK blocks together into an 
extended pipeline which follows the Fast Marching Segmentation example given 
in the ITK Software Guide. The model also demonstrates the use of the 
NodeContainer special block.

A 3-dimensional MRI of the brain is passed as input to the 
CurvatureAnisotropicDiffusionImageFilter. The output is a smoothed image 
which is then passed to the GradientMagnitudeRecursiveGaussianImageFilter and 
then to the SigmoidImageFilter before finally being used as input to the 
FastMarchingImageFilter.

The FastMarchingImageFilter requires a set of one or more seed points to 
begin segmentation. In the model, these seeds are set using the SimITK 
NodeContainer special block. This block takes two parameters, an array of N 
seed values and an array of respective indices which will have a size of 
N*ImageDimensionality. Once the parameters have been set and the output of 
the NodeContainer block has been connected to the special third input of the 
FastMarchingImageFilter block, the filter can be used.

This example model shows a segmentation of white matter. The parameters of 
the blocks in this model are set as follows:

itkReaderFL3
    FileName             'subject04_t1w_p4_float.mha'
    
itkCurvatureAnisotropicDiffusionImageFilterFL3
    ConductanceParameter 9.0
    NumberOfIterations   5
    TimeStep             0.0625

itkGradientMagnitudeRecursiveGaussianImageFilterFL3
    Sigma                1.0
    
itkSigmoidImageFilterFL3
    Alpha                -15
    Beta                 2.0
    OutputMaximum        1
    OutputMinimum        0

itkNodeContainerFL3
    Value                [0.5]
    Index                [101 118 98]

itkFastMarchingImageFilterFL3
    StoppingValue        100

itWriterFL3
    FileName             'outputFastMarchingFL3Model.mhd'


ResampleFL3Model.mdl
--------------------

This model is similar to the ResampleUC2Model but instead uses 3-dimensional 
data. The transform must now be taken from the 3D Transform library and here 
we choose the CenteredEuler3DTransform3D block. This block takes an array of 
9 elements which specify a rotation, the center of rotation and a 
translation. We specify a small rotation of 20 around the Z-axis and connect 
the transform to the ResampleImageFilter block.

The parameters of the blocks in this model are set as follows:

itkReaderFL3
    FileName             'subject04_t1w_p4_float.mha'

itkCenteredEuler3DTransform3D
    Parameters           [0 0 20 127.5 127.5 90 0 0 0]
    FixedParameters      []

itkResampleImageFilterFL3
    DefaultPixelValue    0
    OutputOrigin         [0 0 0]
    OutputSpacing        [1 1 1]
    Size                 [256 256 181]

itWriterFL3
    FileName             'outputResampleFL3Model.mhd'
