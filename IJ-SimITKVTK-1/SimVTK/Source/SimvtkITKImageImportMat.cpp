/*
=================
Copyright (c) Queen's University
All rights reserved.

See Copyright.txt for more details.
=================



 * You must specify the S_FUNCTION_NAME as the name of your S-function.
 */

#define S_FUNCTION_NAME  SimvtkITKImageImportMat
#define S_FUNCTION_LEVEL 2
#define MATLAB_MEX_FILE

#define IMAGE_DIMENSIONALITY 2
#define INPUT_IMAGE_PIXELTYPE float


/*
 * Need to include simstruc.h for the definition of the SimStruct and
 * its associated macro definitions.
 *
 * The following headers are included by matlabroot/simulink/include/simstruc.h
 * when compiling as a MEX file:
 *
 *   matlabroot/extern/include/tmwtypes.h    - General types, e.g. real_T
 *   matlabroot/extern/include/mex.h         - MATLAB MEX file API routines
 *   matlabroot/extern/include/matrix.h      - MATLAB MEX file API routines
 *
 * The following headers are included by matlabroot/simulink/include/simstruc.h
 * when compiling your S-function with RTW:
 *
 *   matlabroot/extern/include/tmwtypes.h    - General types, e.g. real_T
 *   matlabroot/rtw/c/libsrc/rt_matrx.h      - Macros for MATLAB API routines
 *
 */
#include "simstruc.h"
#include "vtkImageImport.h"

//must include if written in c++
#ifdef __cplusplus
extern "C" { // use the C fcn-call standard for all functions  
#endif       // defined within this scope


/* Function: mdlInitializeSizes ===============================================
 * Abstract:
 *    The sizes information is used by Simulink to determine the S-function
 *    block's characteristics (number of inputs, outputs, states, etc.).
 *
 *    The direct feedthrough flag can be either 1=yes or 0=no. It should be
 *    set to 1 if the input, "u", is used in the mdlOutput function. Setting
 *    this to 0 is akin to making a promise that "u" will not be used in the
 *    mdlOutput function. If you break the promise, then unpredictable results
 *    will occur.
 *
 *    The NumContStates, NumDiscStates, NumInputs, NumOutputs, NumRWork,
 *    NumIWork, NumPWork NumModes, and NumNonsampledZCs widths can be set to:
 *       DYNAMICALLY_SIZED    - In this case, they will be set to the actual
 *                              input width, unless you are have a
 *                              mdlSetWorkWidths to set the widths.
 *       0 or positive number - This explicitly sets item to the specified
 *                              value.
 */
static void mdlInitializeSizes(SimStruct *S)
{
	int nInputPorts  = 2;  /* number of input ports  from XML document for optional/repeatable stuff */
	int nOutputPorts = 0;  /* number of output ports that the user has specified will be wanted. */
				
	const int needsInput   = 1;  /* direct feed through    */

	int i = 0;
	
	DTypeId id;
	
	if (ssGetDataTypeId((S), "vtkObject") == INVALID_DTYPE_ID)
	{
		int status;
		id = ssRegisterDataType(S, "vtkObject");
		if(id == INVALID_DTYPE_ID) return;
		status = ssSetDataTypeSize(S, id, sizeof(void *));
		if (status == 0) return;
	}
	else 
	{
		id = ssGetDataTypeId(S, "vtkObject");
	}

	ssSetNumSFcnParams(S, 1);  /* Number of expected parameters = number of possible inputs + 3*number of possible parameters in XML */
	if (ssGetNumSFcnParams(S) != ssGetSFcnParamsCount(S)) {
		return;
	}
	
		ssAllowSignalsWithMoreThan2D(S);

	ssSetNumContStates(    S, 0);   /* number of continuous states           */
	ssSetNumDiscStates(    S, 0);   /* number of discrete states             */
	
	vtkImageImport *filter = vtkImageImport::New();
	nInputPorts += filter->GetNumberOfInputPorts();
	nOutputPorts += filter->GetNumberOfOutputPorts();
	filter->Delete();

	//setup 2 input ports
	if (!ssSetNumInputPorts(S, nInputPorts)) return;

	//setup input port for image information
	ssSetInputPortDataType( S, 0, SS_DOUBLE);
	ssSetInputPortDimensionInfo(S, 0, DYNAMIC_DIMENSION);

	
	//setup input port for image data
	ssSetInputPortDimensionInfo(S, 1, DYNAMIC_DIMENSION);
	ssSetInputPortDataType( S, 1, DYNAMICALLY_TYPED);
	
	//set all input ports to be contiguous
	ssSetInputPortRequiredContiguous(S, 0, true);
	ssSetInputPortRequiredContiguous(S, 1, true);

	//both input ports are set to have direct feedthrough since they are used in mdlOutputs
	ssSetInputPortDirectFeedThrough(S, 0, 1);
	ssSetInputPortDirectFeedThrough(S, 1, 1);
	
	for (i = 2; i < nInputPorts ; i++) // for all the input ports that will be pointers
	{
		ssSetInputPortWidth(S, i, 1); 
		ssSetInputPortDirectFeedThrough(S, i, 1);
		ssSetInputPortDataType(S, i, id);  
		ssSetInputPortRequiredContiguous(S, i, 1);  // require that all input ports are contiguous
	}

	//setting number of output ports 
	if (!ssSetNumOutputPorts(S, nOutputPorts)) return;

	/*
	 * Set output port dimensions for each output port.
	 * Since each output will always be passed as a pointer, so only need to keep track of current location in simulink port list.
	 */
    
    for(i = 0; i < nOutputPorts; i++)
    {
        ssSetOutputPortWidth(S, i, 1);
        ssSetOutputPortDataType(S, i, id);
    }


	ssSetNumSampleTimes(   S, 1);   /* number of sample times                */

	ssSetNumRWork(         S, 0);   /* number of real work vector elements   */
	ssSetNumIWork(         S, 0);   /* number of integer work vector elements*/
	ssSetNumPWork(         S, 0);   /* number of pointer work vector elements*/
	ssSetNumModes(         S, 0);   /* number of mode work vector elements   */
	ssSetNumNonsampledZCs( S, 0);   /* number of nonsampled zero crossings   */
	ssSetOptions(          S, SS_OPTION_CALL_TERMINATE_ON_EXIT);   /* general options (SS_OPTION_xx)        */

} /* end mdlInitializeSizes */


/* Function: mdlInitializeSampleTimes =========================================
 * Abstract:
 *
 *    This function is used to specify the sample time(s) for your S-function.
 *    You must register the same number of sample times as specified in
 *    ssSetNumSampleTimes. If you specify that you have no sample times, then
 *    the S-function is assumed to have one inherited sample time.
 *
 */
static void mdlInitializeSampleTimes(SimStruct *S)
{
	/* Register one pair for each sample time */
	ssSetSampleTime(S, 0, CONTINUOUS_SAMPLE_TIME);
	ssSetOffsetTime(S, 0, 0.0);

} /* end mdlInitializeSampleTimes */


#define MDL_START  /* Change to #undef to remove function */
#if defined(MDL_START)
  /* Function: mdlStart =======================================================
   * Abstract:
   *    This function is called once at start of model execution. If you
   *    have states that should be initialized once, this is the place
   *    to do it.
   */
static void mdlStart(SimStruct *S)
{
    	int inputPortIndex = 0, nInputPorts = 0, outputPortIndex = 0, i = 0, j = 0; // used to pass through list of parameters and do correct thing with each entered parameter
	//create the vtkObject and store pointer in user data
	vtkImageImport *filter = vtkImageImport::New();
	ssSetUserData(S, (void*)filter);
	
	vtkAlgorithmOutput **nextInput;
	for (i = 0; i < filter->GetNumberOfInputPorts(); i++)
	{
		nextInput = (vtkAlgorithmOutput**) ssGetInputPortSignal(S,i+2); //start after the image data (if need to add any extra inputs)
		filter->SetInputConnection(i, nextInput[0]);
	}
    // dim[0] = rows , dim[1] = col
    int* dimensions0 = ssGetInputPortDimensions(S, 0); //info
	int* dimensions1 = ssGetInputPortDimensions(S, 1); //image

	int numDimensions0 = ssGetInputPortNumDimensions(S, 0); //info
	int numDimensions1 = ssGetInputPortNumDimensions(S, 1); //image
    
    
    
    if (numDimensions1 != 2 && numDimensions1 != 3){
        ssSetErrorStatus(S, "Image Dimension unusable in Image Import.  Only 2D and 3D available.");
		return;
    }

	// Set up all parameters that will be constant throughout the program and all pointers  (which also stay constant)

	double *InputOriginAndSpacing = (double*) ssGetInputPortSignal(S,0);
	double InputOrigin[3];
	double InputSpacing[3];
    
	for (int i=0; i<dimensions0[1]; i++) {
        cout << InputOriginAndSpacing[i];
        cout << InputOriginAndSpacing[(i+dimensions0[1])];
		InputOrigin[i] = InputOriginAndSpacing[i];
		InputSpacing[i] = InputOriginAndSpacing[(i+dimensions0[1])];
	}
    
    // Get input size info from the input data itself
    // To avoid type cast to the pointer, we are copying to an unsigned int array
    unsigned int InputSize[3];
    int* InputSizeInt = ssGetInputPortDimensions(S,1);
    for(int i=0; i<numDimensions1; i++){
        InputSize[i] = InputSizeInt[i];
    }
	
	// Get signal from image data port and cast to correct type
	void* InputPortMatrix = (void*) ssGetInputPortSignal(S,1);

	filter->SetImportVoidPointer(InputPortMatrix);
	
	if (numDimensions1 == 2){
		filter->SetDataSpacing(InputSpacing[0],InputSpacing[1], 0);
        filter->SetDataOrigin(InputOrigin[0],InputOrigin[1], 0);
        filter->SetWholeExtent(0,InputSize[0]-1, 0, InputSize[1]-1, 0, 0);
	}
	else if (numDimensions1 == 3){
		filter->SetDataSpacing(InputSpacing);
        filter->SetDataOrigin(InputOrigin);
        filter->SetWholeExtent(0,InputSize[0]-1, 0, InputSize[1]-1, 0, InputSize[2]-1);
	}

    filter->SetDataExtentToWholeExtent();
    
    switch((int)mxGetScalar(ssGetSFcnParam(S,0)))
    {
    case 1:
        filter->SetDataScalarTypeToDouble();
    break;
    case 2:
        filter->SetDataScalarTypeToFloat();
    break;
    case 3:
        filter->SetDataScalarTypeToInt();
    break;
    case 4:
        filter->SetDataScalarTypeToShort();
    break;
    case 5:
        filter->SetDataScalarTypeToUnsignedShort();
    break;
    case 6:
        filter->SetDataScalarTypeToUnsignedChar();
    break;
    }
    
    	// take care of all outputs created by the vtkObject last 
	for (i = 0; i < ssGetNumOutputPorts(S) && ssGetOutputPortConnected(S, i); i++)
	{
		vtkAlgorithmOutput **OutputPort = (vtkAlgorithmOutput**) ssGetOutputPortSignal(S,i);
		OutputPort[0] =  filter->GetOutputPort(i);
	}
}
#endif /*  MDL_START */

/* Function: mdlOutputs =======================================================
 * Abstract:
 *    In this function, you compute the outputs of your S-function
 *    block. Generally outputs are placed in the output vector(s),
 *    ssGetOutputPortSignal.
 */
static void mdlOutputs(SimStruct *S, int_T tid)
{
} /* end mdlOutputs */

#define MDL_SET_INPUT_PORT_DIMENSION_INFO
#if defined(MDL_SET_INPUT_PORT_DIMENSION_INFO) && defined(MATLAB_MEX_FILE)
  /* Function: mdlSetInputPortDimensionInfo ====================================
   * Abstract:
   *    This method is called with the candidate dimensions for an input port
   *    with unknown dimensions. If the proposed dimensions are acceptable, the 
   *    method should go ahead and set the actual port dimensions.  
   *    If they are unacceptable an error should be generated via 
   *    ssSetErrorStatus.  
   *    Note that any other input or output ports whose dimensions are  
   *    implicitly defined by virtue of knowing the dimensions of the given 
   *    port can also have their dimensions set.
   *
   *    See matlabroot/simulink/src/sfun_matadd.c for an example. 
   */
static void mdlSetInputPortDimensionInfo(SimStruct *S, int_T port,
                                         const DimsInfo_T *dimsInfo)
{
	//dynamically set input port dimensions from the input signal at runtime
	if(!ssSetInputPortDimensionInfo(S, port, dimsInfo)) return;

	//dynamically set output port dimensions at runtime
	//these will be set to be the same as the input port dimensions
	//future work: accomodate filters whose input and output port dimensions differ
	//if(!ssSetOutputPortDimensionInfo(S, port, dimsInfo)) return;
}
#endif /* MDL_SET_INPUT_PORT_DIMENSION_INFO */

#define MDL_SET_OUTPUT_PORT_DIMENSION_INFO
#if defined(MDL_SET_OUTPUT_PORT_DIMENSION_INFO) && defined(MATLAB_MEX_FILE)
  /* Function: mdlSetOutputPortDimensionInfo ===================================
   * Abstract:
   *    This method is called with the candidate dimensions for an output port 
   *    with unknown dimensions. If the proposed dimensions are acceptable, the 
   *    method should go ahead and set the actual port dimensions.  
   *    If they are unacceptable an error should be generated via 
   *    ssSetErrorStatus.  
   */
static void mdlSetOutputPortDimensionInfo(SimStruct *S, int_T port,
											const DimsInfo_T *dimsInfo)
{
	//dynamically set ouput port dimensions from the ouput signal at runtime
	if(!ssSetOutputPortDimensionInfo(S, port, dimsInfo)) return;
}
#endif /* MDL_SET_OUTPUT_PORT_DIMENSION_INFO */

#define MDL_SET_DEFAULT_PORT_DIMENSION_INFO /* Change to #define to add fcn */
#if defined(MDL_SET_DEFAULT_PORT_DIMENSION_INFO) && defined(MATLAB_MEX_FILE)
  /* Function: mdlSetDefaultPortDimensionInfo ==================================
   * Abstract:
   *    This method is called when there is not enough information in your
   *    model to uniquely determine the port dimensionality of signals
   *    entering or leaving your block. When this occurs, Simulink's
   *    dimension propagation engine calls this method to ask you to set
   *    your S-functions default dimensions for any input and output ports
   *    that are dynamically sized.
   *
   *    If you do not provide this method and you have dynamically sized ports
   *    where Simulink does not have enough information to propagate the
   *    dimensionality to your S-function, then Simulink will set these unknown
   *    ports to the 'block width' which is determined by examining any known
   *    ports. If there are no known ports, the width will be set to 1.
   *
   *    See matlabroot/simulink/src/sfun_matadd.c for an example. 
   */
  static void mdlSetDefaultPortDimensionInfo(SimStruct *S)
  {
	  /*
	  
	//set the default for the dynamically sized output to be 100
	if(!ssSetOutputPortVectorDimension(S, 0, 100)) return;
    
    //set the default for the dynamically sized inputs to be 1
    if(!ssSetInputPortVectorDimension(S, 0, 2)) return;
    if(!ssSetInputPortVectorDimension(S, 2, 900000)) return;
	*/

  } 
#endif /* MDL_SET_DEFAULT_PORT_DIMENSION_INFO */

	#define MDL_SET_INPUT_PORT_DATA_TYPE   /* Change to #undef to remove function */
#if defined(MDL_SET_INPUT_PORT_DATA_TYPE) && defined(MATLAB_MEX_FILE)
  /* Function: mdlSetInputPortDataType =========================================
   * Abstract:
   *    This method is called with the candidate data type id for a dynamically
   *    typed input port.  If the proposed data type is acceptable, the method
   *    should go ahead and set the actual port data type using
   *    ssSetInputPortDataType.  If the data type is unacceptable an error
   *    should generated via ssSetErrorStatus.  Note that any other dynamically
   *    typed input or output ports whose data types are implicitly defined by
   *    virtue of knowing the data type of the given port can also have their
   *    data types set via calls to ssSetInputPortDataType or 
   *    ssSetOutputPortDataType.  
   *
   *    See matlabroot/simulink/include/simstruc_types.h for built-in
   *    type defines: SS_DOUBLE, SS_BOOLEAN, etc.
   *
   *    See matlabroot/simulink/src/sfun_dtype_io.c for an example. 
   */
  static void mdlSetInputPortDataType(SimStruct *S, int portIndex,DTypeId dType)
  {
			//dynamically set input port dimensions from the input signal at runtime
		if(!ssSetInputPortDataType(S, portIndex, dType)) return;
  } /* mdlSetInputPortDataType */
#endif /* MDL_SET_INPUT_PORT_DATA_TYPE */


#define MDL_SET_OUTPUT_PORT_DATA_TYPE  /* Change to #undef to remove function */
#if defined(MDL_SET_OUTPUT_PORT_DATA_TYPE) && defined(MATLAB_MEX_FILE)
  /* Function: mdlSetOutputPortDataType ========================================
   * Abstract:
   *    This method is called with the candidate data type id for a dynamically
   *    typed output port.  If the proposed data type is acceptable, the method
   *    should go ahead and set the actual port data type using
   *    ssSetOutputPortDataType.  If the data type is unacceptable an error
   *    should generated via ssSetErrorStatus.  Note that any other dynamically
   *    typed input or output ports whose data types are implicitly defined by
   *    virtue of knowing the data type of the given port can also have their
   *    data types set via calls to ssSetInputPortDataType or 
   *    ssSetOutputPortDataType.  
   *
   *    See matlabroot/simulink/src/sfun_dtype_io.c for an example. 
   */
  static void mdlSetOutputPortDataType(SimStruct *S,int portIndex,DTypeId dType)
  {
		//dynamically set ouput port dimensions from the ouput signal at runtime
		if(!ssSetOutputPortDataType(S, portIndex, dType)) return;
  } /* mdlSetOutputPortDataType */
#endif /* MDL_SET_OUTPUT_PORT_DATA_TYPE */

/* Function: mdlTerminate =====================================================
 * Abstract:
 *    In this function, you should perform any actions that are necessary
 *    at the termination of a simulation.  For example, if memory was allocated
 *    in mdlStart, this is the place to free it.
 *
 */
static void mdlTerminate(SimStruct *S)
{
	//Free memory used by filter
	vtkImageImport *filter = (vtkImageImport*) ssGetUserData(S);
	if (filter != NULL) 
	{
		filter->Delete();	 
	} 
}

/*=============================*
 * Required S-function trailer *
 *=============================*/

#ifdef  MATLAB_MEX_FILE    /* Is this file being compiled as a MEX-file? */
#include "simulink.c"      /* MEX-file interface mechanism */
#else
#include "cg_sfun.h"       /* Code generation registration function */
#endif

#ifdef __cplusplus
} // end of extern "C" scope
#endif
