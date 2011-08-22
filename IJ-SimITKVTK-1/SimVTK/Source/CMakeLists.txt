PROJECT(SIMVTK)

# CMake version requirements
CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

# Look for a VTK build directory
FIND_PACKAGE(VTK)
IF (VTK_FOUND)
  INCLUDE (${VTK_USE_FILE})
ENDIF (VTK_FOUND)

#-----------------------------------------------------------------------------
# Output directories.
IF(NOT LIBRARY_OUTPUT_PATH)
  SET(LIBRARY_OUTPUT_PATH ${SIMVTK_BINARY_DIR}/bin CACHE INTERNAL
    "Single output directory for building all libraries.")
ENDIF(NOT LIBRARY_OUTPUT_PATH)
IF(NOT EXECUTABLE_OUTPUT_PATH)
  SET(EXECUTABLE_OUTPUT_PATH ${SIMVTK_BINARY_DIR}/bin CACHE INTERNAL
    "Single output directory for building all executables.")
ENDIF(NOT EXECUTABLE_OUTPUT_PATH)

# Include the config type
SET(SIMVTK_LIBRARY_DIR ${LIBRARY_OUTPUT_PATH}/${CMAKE_CFG_INTDIR})
SET(SIMVTK_EXECUTABLE_DIR ${EXECUTABLE_OUTPUT_PATH}/${CMAKE_CFG_INTDIR})

# XML and CPP output directories
SET(VTKXML_OUTPUT_DIR ${SIMVTK_BINARY_DIR}/vtkXML)
#SET(SIMCPP_OUTPUT_DIR ${LIBRARY_OUTPUT_PATH})
# It should be set to this instead:
SET(SIMCPP_OUTPUT_DIR ${SIMVTK_BINARY_DIR}/vtkXML)

#-----------------------------------------------------------------------------
# The vtkXML executable
SUBDIRS(vtkXML)

# Get the full path to the vtkXML
SET(VTKXML_EXE ${SIMVTK_EXECUTABLE_DIR}/vtkXML)

# Get the hints file, set as an advanced option
FIND_FILE(VTKXML_HINTS xmlhints ${SIMVTK_SOURCE_DIR}/vtkXML
          NO_CMAKE_FIND_ROOT_PATH)
MARK_AS_ADVANCED(VTKXML_HINTS)

#-----------------------------------------------------------------------------
# Include the contents of all the kit .cmake files.
# This provides a list of the classes included in VTK.
INCLUDE("${SIMVTK_SOURCE_DIR}/CMake/vtkIncludeAllKits.cmake")

# This will be a list of targets for all the XML files
SET(VTKXML_TARGETS)

FOREACH(VTK_KIT ${VTK_KITS})

  SET(KIT_NAME "${VTK_${VTK_KIT}_NAME}")
  SET(KIT_HEADER_DIR "${VTK_${VTK_KIT}_HEADER_DIR}")
  SET(KIT_CLASSES "${VTK_${VTK_KIT}_CLASSES}")

  # To store a list of all xml files
  SET(TMP_XML_FILES)

  FOREACH(ONE_CLASS ${KIT_CLASSES})

    IF(NOT "${VTK_CLASS_WRAP_EXCLUDE_${ONE_CLASS}}" EQUAL 1)

      IF("${VTK_CLASS_ABSTRACT_${ONE_CLASS}}" EQUAL 1)
        SET(TMP_CONCRETE 0)
      ELSE("${VTK_CLASS_ABSTRACT_${ONE_CLASS}}" EQUAL 1)
        SET(TMP_CONCRETE 1)
      ENDIF("${VTK_CLASS_ABSTRACT_${ONE_CLASS}}" EQUAL 1)

      # In case we were given a path with the class name
      GET_FILENAME_COMPONENT(TMP_CLASS ${ONE_CLASS} NAME_WE)
      GET_FILENAME_COMPONENT(TMP_DIR ${ONE_CLASS} PATH)
      IF("${TMP_DIR}" STREQUAL "")
        SET(TMP_HEADER_DIR ${KIT_HEADER_DIR})
      ELSE("${TMP_DIR}" STREQUAL "")
        SET(TMP_HEADER_DIR ${TMP_DIR})
      ENDIF("${TMP_DIR}" STREQUAL "")
 
      SET(TMP_INPUT "${TMP_HEADER_DIR}/${TMP_CLASS}.h")

      # add custom command to output
      ADD_CUSTOM_COMMAND(
        OUTPUT ${VTKXML_OUTPUT_DIR}/${TMP_CLASS}.xml
        DEPENDS ${VTKXML_EXE} ${VTKXML_HINTS} ${TMP_INPUT}
        COMMAND ${VTKXML_EXE}
        ARGS ${TMP_INPUT} ${VTKXML_HINTS} ${TMP_CONCRETE}
          ${VTKXML_OUTPUT_DIR}/${TMP_CLASS}.xml
        COMMENT "XML Wrapping - generating ${TMP_CLASS}.xml"
        )

      SET(TMP_XML_FILES ${TMP_XML_FILES}
        ${VTKXML_OUTPUT_DIR}/${TMP_CLASS}.xml)

    ENDIF(NOT "${VTK_CLASS_WRAP_EXCLUDE_${ONE_CLASS}}" EQUAL 1)

  ENDFOREACH(ONE_CLASS "${KIT_CLASSES}")

  # Add a custom target for the kit XML
  ADD_CUSTOM_TARGET(vtk${KIT_NAME}XML DEPENDS ${TMP_XML_FILES})
  SET(VTKXML_TARGETS ${VTKXML_TARGETS} vtk${KIT_NAME}XML)

ENDFOREACH(VTK_KIT ${VTK_KITS})

# Add a custom target for all vtkXML outputs
ADD_CUSTOM_TARGET(vtkAllKitsXML ALL)
ADD_DEPENDENCIES(vtkAllKitsXML ${VTKXML_TARGETS})

#-----------------------------------------------------------------------------
# Disable deprecation warnings for standard C and STL functions
# in VS2005 and later
IF(CMAKE_COMPILER_2005)
  ADD_DEFINITIONS(-D_CRT_SECURE_NO_DEPRECATE -D_CRT_NONSTDC_NO_DEPRECATE)
  ADD_DEFINITIONS(-D_SCL_SECURE_NO_DEPRECATE)
ENDIF(CMAKE_COMPILER_2005)

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

# Set any extra source files (if any) needed for the dlls
#SET(SIMVTK_EXTRA_SRCS)

# Current list of classes that were not able to compile properly
# due to various problems that will soon be fixed
SET(SKIP_CLASSES
vtkWidgetEvent
vtkSphereHandleRepresentation
vtkPolygonalHandleRepresentation3D
vtkPointHandleRepresentation3D
vtkPointHandleRepresentation2D
vtkLineRepresentation
vtkConstrainedPointHandleRepresentation
vtkXYPlotActor
vtkAxisActor
vtkOpenGLImageMapper
vtkVolumeProperty
vtkVolumeCollection
vtkTextActor
vtkScaledTextActor
vtkRendererCollection
vtkRenderWindowCollection
vtkProp3DCollection
vtkMapperCollection
vtkLightCollection
vtkInteractorStyleFlight
vtkImageMapper
vtkCullerCollection
vtkActorCollection
vtkImageMask
vtkImageExtractComponents
vtkImageConvolve
vtkSpherePuzzleArrows
vtkOutlineSource
vtkOutlineCornerSource
vtkModelMetadata
vtkImageReader2Collection
vtkUnstructuredGrid
vtkStructuredPointsCollection
vtkPolyDataCollection
vtkGenericAttributeCollection
vtkGenericRenderWindowInteractor
vtkDataSetCollection
vtkDataObjectCollection
vtkColorTransferFunction
vtkActor2DCollection
vtkWindowLevelLookupTable
vtkTransformCollection
vtkPropCollection
vtkPlaneCollection
vtkObjectFactoryCollection
vtkImplicitFunctionCollection
vtkIdListCollection
vtkDataArrayCollection
vtkAssemblyPath
vtkWin32OpenGLRenderWindow
vtkXOpenGLRenderWindow
vtkSpatialRepresentationFilter
vtkSESAMEReader
vtkPLOT3DReader
vtkStructuredPointsGeometryFilter
vtkQuadricClustering
vtkBMPReader
vtkGeoComputeTextureCoordinates
vtkImageStencilSource
vtkDataWriter
vtkTextMapper
vtkOpenGLFreeTypeTextMapper
)

# Copy the one "special" class source file
# (this should be a build rule, rather than a copy done by cmake)
EXECUTE_PROCESS(
  COMMAND ${CMAKE_COMMAND} -E copy
    "${CMAKE_CURRENT_SOURCE_DIR}/SimvtkITKImageImportMat.cpp"
    "${SIMCPP_OUTPUT_DIR}/SimvtkITKImageImportMat.cpp" 
)

#----------------------------------------------------------------------
# Create the source code for all S-Functions

# This will be a list of targets for all the cpp files
SET(VTKCPP_TARGETS)

# Sets the XML file and perl scripts to be used
SET(PERL_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/vtkBlockGenerator.pl")

FOREACH(VTK_KIT ${VTK_KITS})

  SET(KIT_NAME "${VTK_${VTK_KIT}_NAME}")
  SET(KIT_HEADER_DIR "${VTK_${VTK_KIT}_HEADER_DIR}")
  SET(KIT_CLASSES "${VTK_${VTK_KIT}_CLASSES}")

  #MESSAGE("${KIT_NAME} ${KIT_HEADER_DIR}")

  SET(CLASS_COUNTER 0)

  # To store a list of all cpp files for this Kit
  SET(TMP_CPP_FILES)
  # Store the ITKImageImport File first (if is in imaging)
  IF("${KIT_NAME}" STREQUAL "Imaging")
    SET(TMP_CPP_FILES ${TMP_CPP_FILES}
      "${SIMCPP_OUTPUT_DIR}/SimvtkITKImageImportMat.cpp")
    SET(CLASS_COUNTER 1)
  ENDIF("${KIT_NAME}" STREQUAL "Imaging")

  FOREACH(ONE_CLASS ${KIT_CLASSES})

    IF(NOT "${VTK_CLASS_WRAP_EXCLUDE_${ONE_CLASS}}" EQUAL 1)
      IF(NOT "${VTK_CLASS_ABSTRACT_${ONE_CLASS}}" EQUAL 1)

        # In case we were given a path with the class name
        GET_FILENAME_COMPONENT(TMP_CLASS ${ONE_CLASS} NAME_WE)
        GET_FILENAME_COMPONENT(TMP_DIR ${ONE_CLASS} PATH)
        IF("${TMP_DIR}" STREQUAL "")
          SET(TMP_HEADER_DIR ${KIT_HEADER_DIR})
        ELSE("${TMP_DIR}" STREQUAL "")
          SET(TMP_HEADER_DIR ${TMP_DIR})
        ENDIF("${TMP_DIR}" STREQUAL "")

        LIST(FIND SKIP_CLASSES ${TMP_CLASS} RESULT)
        IF (${RESULT} EQUAL -1)
          SET(TMP_INPUT "${VTKXML_OUTPUT_DIR}/${TMP_CLASS}.xml")

          # add custom command to output
          ADD_CUSTOM_COMMAND(
            OUTPUT ${SIMCPP_OUTPUT_DIR}/Sim${TMP_CLASS}Mat.cpp
            DEPENDS ${TMP_INPUT} ${PERL_SCRIPT}
            COMMAND ${PERL_EXECUTABLE}  
            # Make sure perl has access to modules in the source directory
            ARGS "-I" ${CMAKE_CURRENT_SOURCE_DIR} ${PERL_SCRIPT}
              "-GENERATE" ${TMP_INPUT} ${LIBRARY_OUTPUT_PATH}
              ${SIMCPP_OUTPUT_DIR} ${KIT_NAME} ${VTKXML_OUTPUT_DIR}
              ${CMAKE_CURRENT_SOURCE_DIR} ${CLASS_COUNTER}
            COMMENT "Building S-Function and Callbacks - ${TMP_CLASS}"
            )
              
          SET(TMP_CPP_FILES ${TMP_CPP_FILES}
            ${SIMCPP_OUTPUT_DIR}/Sim${TMP_CLASS}Mat.cpp)

  	  # add 1 to the counter
   	  MATH(EXPR CLASS_COUNTER ${CLASS_COUNTER}+1 )
        ENDIF(${RESULT} EQUAL -1)
      
      ENDIF(NOT "${VTK_CLASS_ABSTRACT_${ONE_CLASS}}" EQUAL 1)
      
    ENDIF(NOT "${VTK_CLASS_WRAP_EXCLUDE_${ONE_CLASS}}" EQUAL 1)

  ENDFOREACH(ONE_CLASS "${KIT_CLASSES}")
  
  # Add a custom target for the kit cpp
  ADD_CUSTOM_TARGET(vtk${KIT_NAME}CPP DEPENDS ${TMP_CPP_FILES})
  ADD_DEPENDENCIES(vtk${KIT_NAME}CPP vtkAllKitsXML)
  SET(VTKCPP_TARGETS ${VTKCPP_TARGETS} vtk${KIT_NAME}CPP)

ENDFOREACH(VTK_KIT ${VTK_KITS})

# Add a custom target for all vtkXML outputs
ADD_CUSTOM_TARGET(vtkAllKitsCPP ALL)
ADD_DEPENDENCIES(vtkAllKitsCPP ${VTKCPP_TARGETS})

#-----------------------------------------------------------------------------
# Create the library (.mdl) files

# This will be a list of targets for all the cpp files
SET(VTKMDL_TARGETS)

FOREACH(VTK_KIT ${VTK_KITS})

  SET(KIT_NAME "${VTK_${VTK_KIT}_NAME}")
  SET(KIT_HEADER_DIR "${VTK_${VTK_KIT}_HEADER_DIR}")
  SET(KIT_CLASSES "${VTK_${VTK_KIT}_CLASSES}")

  # add custom command to output
  ADD_CUSTOM_COMMAND(
    OUTPUT ${LIBRARY_OUTPUT_PATH}/Simvtk${KIT_NAME}Library.mdl
    DEPENDS ${PERL_SCRIPT}
    COMMAND ${PERL_EXECUTABLE} 
    #Make sure perl has access to the modules in the source directory
    ARGS "-I" ${CMAKE_CURRENT_SOURCE_DIR} ${PERL_SCRIPT} "-FINALIZE" "FILE"
      ${LIBRARY_OUTPUT_PATH} ${SIMCPP_OUTPUT_DIR} ${KIT_NAME}
      ${VTKXML_OUTPUT_DIR} ${CMAKE_CURRENT_SOURCE_DIR} ${CLASS_COUNTER}
    COMMAND ${CMAKE_COMMAND}
    ARGS "-E" "remove"
      "${LIBRARY_OUTPUT_PATH}/Simvtk${KIT_NAME}LibraryPosition.in"
      "${LIBRARY_OUTPUT_PATH}/Simvtk${KIT_NAME}LibraryTemp.mdl"
    COMMENT "Finalizing library - ${VTK_KIT}"
  )
  
  SET(TMP_MDL_FILE ${LIBRARY_OUTPUT_PATH}/Simvtk${KIT_NAME}Library.mdl )
  
  ADD_CUSTOM_TARGET(vtk${KIT_NAME}MDL DEPENDS ${TMP_MDL_FILE})
  ADD_DEPENDENCIES(vtk${KIT_NAME}MDL vtkAllKitsCPP)
  SET(VTKMDL_TARGETS ${VTKMDL_TARGETS} vtk${KIT_NAME}MDL)

ENDFOREACH(VTK_KIT ${VTK_KITS})

# Add a custom target for all vtkXML outputs
ADD_CUSTOM_TARGET(vtkAllKitsMDL ALL)
ADD_DEPENDENCIES(vtkAllKitsMDL ${VTKMDL_TARGETS})

#-----------------------------------------------------------------------------
# compile the S-Functions

FOREACH(VTK_KIT ${VTK_KITS})

  SET(KIT_NAME "${VTK_${VTK_KIT}_NAME}")
  SET(KIT_HEADER_DIR "${VTK_${VTK_KIT}_HEADER_DIR}")
  SET(KIT_CLASSES "${VTK_${VTK_KIT}_CLASSES}")
  SET(KIT_LIB_DEPENDS "${vtk${KIT_NAME}_LIB_DEPENDS}")

  IF(KIT_NAME STREQUAL "Imaging")
    SET(KIT_CLASSES ${KIT_CLASSES} vtkITKImageImport)
  ENDIF(KIT_NAME STREQUAL "Imaging")

  FOREACH(ONE_CLASS ${KIT_CLASSES})

    IF(NOT "${VTK_CLASS_WRAP_EXCLUDE_${ONE_CLASS}}" EQUAL 1)
      IF(NOT "${VTK_CLASS_ABSTRACT_${ONE_CLASS}}" EQUAL 1)

        # In case we were given a path with the class name
        GET_FILENAME_COMPONENT(TMP_CLASS ${ONE_CLASS} NAME_WE)
        GET_FILENAME_COMPONENT(TMP_DIR ${ONE_CLASS} PATH)
        IF("${TMP_DIR}" STREQUAL "")
          SET(TMP_HEADER_DIR ${KIT_HEADER_DIR})
        ELSE("${TMP_DIR}" STREQUAL "")
          SET(TMP_HEADER_DIR ${TMP_DIR})
        ENDIF("${TMP_DIR}" STREQUAL "")
        
        #ignore the files that were problems
        LIST(FIND SKIP_CLASSES ${TMP_CLASS} TMP_RESULT)
        
        IF(${TMP_RESULT} EQUAL -1)
        
          ADD_LIBRARY("Sim${TMP_CLASS}Mat" SHARED
            "${SIMCPP_OUTPUT_DIR}/Sim${TMP_CLASS}Mat.cpp"
    	    ${SIMVTK_EXTRA_SRCS})
          ADD_DEPENDENCIES("Sim${TMP_CLASS}Mat" ${VTKCPP_TARGETS})
          #This is needed for all MATLAB mex files
          IF(WIN32)
            SET_TARGET_PROPERTIES("Sim${TMP_CLASS}Mat" PROPERTIES
              LINK_FLAGS "/export:mexFunction")
          ELSE(WIN32)
            IF("${CMAKE_SIZEOF_VOID_P}" GREATER 4)
              SET_TARGET_PROPERTIES("Sim${TMP_CLASS}Mat"
                PROPERTIES PREFIX "" SUFFIX ".mexa64")
            ELSE("${CMAKE_SIZEOF_VOID_P}" GREATER 4)
              SET_TARGET_PROPERTIES("Sim${TMP_CLASS}Mat"
                PROPERTIES PREFIX "" SUFFIX ".mexglx")
            ENDIF("${CMAKE_SIZEOF_VOID_P}" GREATER 4)
          ENDIF(WIN32)
          TARGET_LINK_LIBRARIES("Sim${TMP_CLASS}Mat"
            vtk${KIT_NAME} ${KIT_LIB_DEPENDS}
            ${MATLAB_LIBRARIES})
        
        ENDIF(${TMP_RESULT} EQUAL -1)
        
      ENDIF(NOT "${VTK_CLASS_ABSTRACT_${ONE_CLASS}}" EQUAL 1)

    ENDIF(NOT "${VTK_CLASS_WRAP_EXCLUDE_${ONE_CLASS}}" EQUAL 1)

  ENDFOREACH(ONE_CLASS "${KIT_CLASSES}")

ENDFOREACH(VTK_KIT ${VTK_KITS})

