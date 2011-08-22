CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

PROJECT(SIMITK)
INCLUDE_REGULAR_EXPRESSION("^.*$")

# Disable deprecation warnings for standard C and STL functions in VS2005 and later
IF(CMAKE_COMPILER_2005)
  ADD_DEFINITIONS(-D_CRT_SECURE_NO_DEPRECATE -D_CRT_NONSTDC_NO_DEPRECATE)
  ADD_DEFINITIONS(-D_SCL_SECURE_NO_DEPRECATE)
ENDIF(CMAKE_COMPILER_2005)

# Find ITK, all the ITK header files, and all the ITK libraries
FIND_PACKAGE(ITK)
IF(ITK_FOUND)
  INCLUDE(${ITK_USE_FILE})
ENDIF(ITK_FOUND)
SET(ITK_LIBS ITKNumerics ITKCommon ITKIO ITKStatistics ITKAlgorithms ITKBasicFilters)

# Find the Perl libraries so we can generate code using perl scripts
FIND_PACKAGE(Perl)

#-----------------------------------------------------------------------------
# Look for MATLAB and define useful variables

IF(WIN32)
  SET(MATLAB_PATH_SEARCH
    "C:/Program Files/MATLAB/R2007a"
    "C:/Program Files/MATLAB/R2007b"
    "C:/Program Files/MATLAB/R2008a"
    "C:/Program Files/MATLAB/R2008b"
  )
ELSE(WIN32)
  SET(MATLAB_PATH_SEARCH
    "/usr/local/matlab74"
    "/usr/local/matlab76"
    "/usr/local/matlab76"
    "/usr/local/matlab77"
  )
ENDIF(WIN32)

FIND_PATH(MATLAB_ROOT patents.txt
  $ENV{MATLAB_ROOT}
  ${MATLAB_PATH_SEARCH}
  DOC "The directory where MATLAB is installed"
)

SET(MATLAB_FOUND 0)
IF(MATLAB_ROOT)
  IF(EXISTS ${MATLAB_ROOT}/patents.txt)
    SET(MATLAB_FOUND 1)
  ENDIF(EXISTS ${MATLAB_ROOT}/patents.txt)
ENDIF(MATLAB_ROOT)

IF(NOT MATLAB_FOUND)
  MESSAGE(FATAL_ERROR "MATLAB not found, please set MATLAB_ROOT")
ENDIF(NOT MATLAB_FOUND)

IF(WIN32)
  SET(MATLAB_ARCH_DIR "${MATLAB_ROOT}/extern/lib/win32/microsoft")
  FIND_LIBRARY(MATLAB_MEX_LIBRARY libmex "${MATLAB_ARCH_DIR}")
  FIND_LIBRARY(MATLAB_MX_LIBRARY libmx "${MATLAB_ARCH_DIR}")
  FIND_LIBRARY(MATLAB_MAT_LIBRARY libmat "${MATLAB_ARCH_DIR}")
  FIND_LIBRARY(MATLAB_ENG_LIBRARY libeng "${MATLAB_ARCH_DIR}")
ELSE(WIN32)
  SET(MATLAB_ROOT "/usr/local/matlab76" CACHE PATH "MATLAB directory")
  IF("${CMAKE_SIZEOF_VOID_P}" GREATER 4)
    SET(MATLAB_ARCH_DIR "${MATLAB_ROOT}/bin/glnxa64")
  ELSE("${CMAKE_SIZEOF_VOID_P}" GREATER 4)
    SET(MATLAB_ARCH_DIR "${MATLAB_ROOT}/bin/glnx86")
  ENDIF("${CMAKE_SIZEOF_VOID_P}" GREATER 4)
  FIND_LIBRARY(MATLAB_MEX_LIBRARY mex "${MATLAB_ARCH_DIR}")
  FIND_LIBRARY(MATLAB_MX_LIBRARY mx "${MATLAB_ARCH_DIR}")
  FIND_LIBRARY(MATLAB_MAT_LIBRARY mat "${MATLAB_ARCH_DIR}")
  FIND_LIBRARY(MATLAB_ENG_LIBRARY eng "${MATLAB_ARCH_DIR}")
ENDIF(WIN32)

FIND_PATH(MATLAB_INCLUDE_DIR "mex.h" "${MATLAB_ROOT}/extern/include")
FIND_PATH(SIMULINK_INCLUDE_DIR "simstruc.h" "${MATLAB_ROOT}/simulink/include")

MARK_AS_ADVANCED(
  MATLAB_MAT_LIBRARY MATLAB_MEX_LIBRARY MATLAB_MX_LIBRARY MATLAB_ENG_LIBRARY
  MATLAB_INCLUDE_DIR SIMULINK_INCLUDE_DIR
)

SET(MATLAB_LIBRARIES
  ${MATLAB_MEX_LIBRARY} ${MATLAB_MX_LIBRARY} ${MATLAB_ENG_LIBRARY})

# Set MATLAB include directories
INCLUDE_DIRECTORIES(${MATLAB_INCLUDE_DIR} ${SIMULINK_INCLUDE_DIR})

#-----------------------------------------------------------------------------

# Set other include directories (especially your own)
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})

#Set Registration helper include directories
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR}/RegistrationHelper)

# Set any extra source files (if any) needed for the dlls
SET(SIMITK_EXTRA_SRCS
   )

#Sets the XML file and perl scripts to be used
SET(XMLFILE "${CMAKE_CURRENT_SOURCE_DIR}/FilterXMLDescriptions.xml")
SET(XMLFILE_TRANSFORMS "${CMAKE_CURRENT_SOURCE_DIR}/TransformXMLDescriptions.xml")
SET(PERL_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/BlockGenerator.pl")
SET(READER_WRITER "${CMAKE_CURRENT_SOURCE_DIR}/ReaderWriterGen.pl")
SET(CONTAINER "${CMAKE_CURRENT_SOURCE_DIR}/ContainerGen.pl")

#Sets the datatypes for each library 
SET(DATATYPES 
    "float"
    "short"
    "unsigned char"
    "unsigned short"
    )
    
# Runs the perl script to determine the names of the filters in XML file.  A string is returned delimited
#by the semicolon (;), which is the cmake separator for lists.  Each filter name is then stored in a list. 
FOREACH(DIMENSIONALITY "2" "3")
  FOREACH(DATATYPE ${DATATYPES})
    EXECUTE_PROCESS(
      COMMAND ${PERL_EXECUTABLE} ${PERL_SCRIPT} "-LIST" ${XMLFILE} ${DIMENSIONALITY} ${DATATYPE} ${DATATYPE} ${CMAKE_CURRENT_BINARY_DIR}   
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      OUTPUT_VARIABLE FILTER_NAMES  
    )
    SET(PRE_SIMITK_BLOCKS ${PRE_SIMITK_BLOCKS} ${FILTER_NAMES})
  ENDFOREACH(DATATYPE ${DATATYPES})
  
  # Transform objects are not specific to pixeltype and only need to be generated once per dimensionality
  EXECUTE_PROCESS(
    COMMAND ${PERL_EXECUTABLE} ${PERL_SCRIPT} "-LIST" ${XMLFILE_TRANSFORMS} ${DIMENSIONALITY} "float" "float" ${CMAKE_CURRENT_BINARY_DIR}   
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE TRANSFORM_NAMES  
  )
SET(PRE_SIMITK_BLOCKS ${PRE_SIMITK_BLOCKS} ${TRANSFORM_NAMES})
ENDFOREACH(DIMENSIONALITY "2" "3")



#Process the file names in the list by adding SimITK in front.  The new file names
#are then stored in a new list. 
FOREACH(PRE_FILE_NAME ${PRE_SIMITK_BLOCKS})
    SET(SIMITK_BLOCKS ${SIMITK_BLOCKS} SimITK${PRE_FILE_NAME})
ENDFOREACH(PRE_FILE_NAME ${PRE_SIMITK_BLOCKS})

FOREACH(DIMENSIONALITY "2" "3")
  FOREACH(DATATYPE ${DATATYPES})
    EXECUTE_PROCESS( #Generates the source code by running perl scripts
      COMMAND ${PERL_EXECUTABLE} ${PERL_SCRIPT} "-GENERATE" ${XMLFILE} ${DIMENSIONALITY} ${DATATYPE} ${DATATYPE} ${CMAKE_CURRENT_BINARY_DIR} 
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}  
    )
    EXECUTE_PROCESS( #Generates source code for the reader and writer
      COMMAND ${PERL_EXECUTABLE} ${READER_WRITER} ${DIMENSIONALITY} ${DATATYPE} ${DATATYPE} ${CMAKE_CURRENT_BINARY_DIR}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    EXECUTE_PROCESS( #Generates source code for the container objects
      COMMAND ${PERL_EXECUTABLE} ${CONTAINER} ${DIMENSIONALITY} ${DATATYPE} ${DATATYPE} ${CMAKE_CURRENT_BINARY_DIR}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
  ENDFOREACH(DATATYPE ${DATATYPES})
  
  EXECUTE_PROCESS( #Generates the source code for transform objects
    COMMAND ${PERL_EXECUTABLE} ${PERL_SCRIPT} "-GENERATE" ${XMLFILE_TRANSFORMS} ${DIMENSIONALITY} "float" "float" ${CMAKE_CURRENT_BINARY_DIR} 
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}  
  )
ENDFOREACH(DIMENSIONALITY "2" "3")

#Adds the reader and writer blocks
SET(SIMITK_BLOCKS ${SIMITK_BLOCKS}
  ReaderFL2
  WriterFL2
  ReaderSS2 
  WriterSS2
  ReaderUC2
  WriterUC2
  ReaderUS2
  WriterUS2
  SimITKContainerUC2
  SimITKContainerUS2
  SimITKContainerSS2
  SimITKContainerFL2
  ReaderFL3
  WriterFL3
  ReaderSS3 
  WriterSS3
  ReaderUC3
  WriterUC3
  ReaderUS3
  WriterUS3
  SimITKContainerUC3
  SimITKContainerUS3
  SimITKContainerSS3
  SimITKContainerFL3
)            

#Sets the directory where the libraries should be stored
SET(LIBRARY_OUTPUT_PATH ${CMAKE_CURRENT_BINARY_DIR})

# Compile the blocks into dynamically linked libraries
FOREACH(ONE_BLOCK ${SIMITK_BLOCKS})
  ADD_LIBRARY("${ONE_BLOCK}Mat" SHARED "${CMAKE_CURRENT_BINARY_DIR}/${ONE_BLOCK}Mat.cpp"
          ${SIMITK_EXTRA_SRCS})
  #This is needed for all MATLAB mex files
  IF(WIN32)
    SET_TARGET_PROPERTIES("${ONE_BLOCK}Mat" PROPERTIES LINK_FLAGS "/export:mexFunction")
  ELSE(WIN32)
    IF("${CMAKE_SIZEOF_VOID_P}" GREATER 4)
      SET_TARGET_PROPERTIES("${ONE_BLOCK}Mat"
                PROPERTIES PREFIX "" SUFFIX ".mexa64")
    ELSE("${CMAKE_SIZEOF_VOID_P}" GREATER 4)
      SET_TARGET_PROPERTIES("${ONE_BLOCK}Mat"
                PROPERTIES PREFIX "" SUFFIX ".mexglx")
    ENDIF("${CMAKE_SIZEOF_VOID_P}" GREATER 4)
  ENDIF(WIN32)
  TARGET_LINK_LIBRARIES("${ONE_BLOCK}Mat" ${ITK_LIBS} ${MATLAB_LIBRARIES})
ENDFOREACH(ONE_BLOCK ${SIMITK_BLOCKS})
