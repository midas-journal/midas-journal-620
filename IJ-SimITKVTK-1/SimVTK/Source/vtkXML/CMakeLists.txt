PROJECT(VTKXML)

# list of sources for executable
SET(vtkXML_SRCS
  vtkParse.tab.c
  vtkXML.c
)

# name of executable
SET(vtkXML_EXE vtkXML)

# Always add current source and build directories to include path
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})

ADD_EXECUTABLE(${vtkXML_EXE} ${vtkXML_SRCS})

