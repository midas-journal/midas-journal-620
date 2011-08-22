SimVTK Project

Adam Campigotto and David Gobbi
July 2008

==================
Building SimVTK
==================

Before building SimVTK, you must first ensure that ITK, MATLAB, Perl and
CMake have been installed. We have successfully built and tested SimVTK using
VTK 5.2, MATLAB 2007a, Perl 5.10.0 and CMake 2.6.

When you build VTK, you must turn BUILD_SHARED_LIBS ON or else your VTK
cannot be used to build SimVTK.


Building on Windows
-------------------

SimVTK has been tested on Windows using Microsoft Visual Studio 2005 as the
compiler.  Because SimVTK uses Simulink, you should have a Simulink license,
and you must have Simulink installed with your copy of Matlab.

  1. Run CMakeSetup.exe. Specify the proper SimVTK source folder and the
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

  3. The SimVTK .mdl Library files will be found in either the
     Release or Debug subdirectory of the "bin" directory, depending
     on your chosen build configuration.  All of the DLLs and matlab
     files will be in the same location.  You can use SimVTK directly
     from this folder, and if you want to try the examples, you should
     copy them to this folder or add this folder to your MATLAB path.


Building on Linux
-------------------

  Because SimVTK uses Simulink, you should have a Simulink license,
  and you must have Simulink installed with your copy of Matlab.

  In order to build SimVTK on Linux, you must use a compiler that is
  compatible with MATLAB.  For Matlab 7.4 (2007a) and 7.6 (2008a), the
  supported compiler is gcc-3.2, but we have also found that gcc-3.4
  and gcc-4.0 work, while gcc-4.2 does not work.

  You must use a copy of VTK that has been built with the same compiler.
  When you build VTK, turn BUILD_SHARED_LIBS ON.  Then build SimVTK
  as follows:


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

  3. Set the VTK_DIR to your VTK binary directory and press "c" again.
     Also set the CMAKE_BUILD_TYPE to the same build type that you
     used for VTK, e.g. CMAKE_BUILD_TYPE=Release.

  4. Press "g" to generate the make files for SimVTK.  When cmake exits,
     type "make" to build SimVTK.

  5. The bin directory will now contain SimVTK .mdl Library files as
     well as SimVTK .mexglx (Linux 32-bit) or .mexa64 (Linux 64-bit) files.
     SimVTK can be used from this directory.  Copy the contents of the
     Examples directory to the bin directory if you want to try them.


==================
Using SimVTK
==================

The examples (below) are the best place to start.  Here are
a few general notes on SimVTK.

The block libraries correspond to the VTK source subdirectories:
  SimvtkCommonLibrary.mdl
  SimvtkFilteringLibrary.mdl
  SimvtkIOLibrary.dml
  SimvtkImagingLibrary.mdl
  SimvtkGraphicsLibrary.mdl
  SimvtkRenderingLibrary.mdl
  etc.

For this release of SimVTK, not all VTK classes have blocks 
(see the SKIP_CLASSES list in CMakeLists.txt), and not all
class methods are supported.

In general, this release supports parameters that have matching
Set/Get methods.  Methods that do not follow the Set/Get paradigm,
or that have parameters that are not all of the same type, are
not yet supported.

In addition, for algorithm subclasses, optional inputs and 
repeating inputs are not yet supported.

Finally, the "close" button on any vtkRenderWindow created from
Simulink will not work as expected.  The "close" button will
either not work (you should stop the model if you want to close
the window), or else pressing it will cause MATLAB to close.
Once we have a Simulink wrapper window for the RenderWindow, this
problem will go away.

Other than the above-noted "incompleteness", while will be fixed
in later revisions, we believe that the vast majority of VTK
features are available from this version of SimVTK.

==================
SimVTK Examples
==================

When running the models, don't close the VTK window.  Always use
the "stop" menu item (or button) on the Simulink model window instead.

------------
ConeInteractor.mdl

   Displays a cone in a window with an interactor so that you can spin it.

------------
MovingCone.mdl

   Displays a cone that has its Center parameter connected to a sinusoid source.

-----------
MovingConeWithTarget.mdl

   Similar to the above, but includes a second object (a sphere) and adds
   the Trackball interaction style.

-----------
PolyDataInteractor.mdl

   Loads the file 'vtk.vtk' and displays it in a window.  Note that if the
   file is not present, VTK will generate tons of error messages.  You can
   try loading other .vtk files by double-clicking the reader.

-----------
GridViewer.mdl

   Creates a "grid" image and displays it with the ImageViewer.  You can also
   try vtkPNGReader or other readers.

-----------
ITK_VTKModel.mdl

   To use this model, you must have both SimITK and SimVTK in the MATLAB path
   (or, just copy all the binary files from each into your MATLAB directory).

   It uses the file 'cthead1.png', which must be in the MATLAB directory.

   When you run the model, it reads it with ITK and applies Canny edge
   detection before passing it to the vtkITKImageImport block so that
   VTK can display it.


==================
Special Topic: Custom Blocks
==================

VTKXML ReadMe
-------------------------

Takes a vtk header file and creates an xml file for use in SimVTK.  It
contains a list of all inputs, outputs, and parameters that have been
chosen to be used in SimVTK.  The hint file is special and contains a
list of certain unwanted parameters.  The hint file does not need to be
included.  Without it, less useful parameters will be added to the xml File.

USAGE: vtkXML <vtk_header> <hint_file> <is_concrete> <output_file>

========

Perl Script README
-------------------------

VTKBlockGenerator.pl: Generates one Simulink S-funtion Block file (.cpp)
and one Matlab Callback file for each filter description in a given XML
file.  It also creates a Matlab Library mdl file.

USAGE: VTKBlockGenerator.pl <XML_filename> <directory>


