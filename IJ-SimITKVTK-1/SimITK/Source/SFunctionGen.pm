package SFunctionGen;

###############################################
# SIMITK Project
#
# Copyright (c) Queen's University
# All rights reserved.
#
# See Copyright.txt for more details.
#
# Karen Li and Jing Xiang
# June 2008
###############################################

use strict;
use Switch;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(SFunctionGen);

# Generates S-Function file.
# Inputs: 1. filterHash reference
#         2. dimensionality
#         3. inputPixeltype
#         4. outputPixeltype
#         5. directory
sub SFunctionGen {

  my ($filterHash, $dimensionality, $inputPixeltype, $outputPixeltype, $directory, $templateFile) = @_;
  
  # Read the input file into a single string
  open (INFILE, "<" . $templateFile);
  undef $/;
  my $content = <INFILE>;
  
  $/ = "\n";
  close INFILE;
  
  # Create the output file
  # Transforms are not specific to pixeltype
  if ($templateFile eq "TransformFilterBlockMat.cpp.in") {
    open (OUTFILE, ">$directory/SimITK" . 
      substr($filterHash->{"Name"},0,length($filterHash->{"Name"}) - 3) . $dimensionality . "DMat.cpp");
  }
  else {
    open (OUTFILE, ">$directory/SimITK" . $filterHash->{"Name"} . "Mat.cpp");
  }
  
  # FILTER_NAME
  $content =~ s/\@FILTER_NAME\@/$filterHash->{"Name"}/g;
  #ITK_FILTER_NAME (the filterName minus its 3-character suffix)
  my $ITKFilterName = substr($filterHash->{"Name"}, 0, length($filterHash->{"Name"}) - 3);
  $content =~ s/\@ITK_FILTER_NAME\@/$ITKFilterName/g;
  # DIMENSIONALITY
  $content =~ s/\@DIMENSIONALITY\@/$dimensionality/g;
  # DIMENSIONALITY_CODE
  my $dimensionalityCode = $dimensionality . "D";
  $content =~ s/\@DIMENSIONALITY_CODE\@/$dimensionalityCode/g;
  # INPUT_PIXELTYPE
  $content =~ s/\@INPUT_PIXELTYPE\@/$inputPixeltype/g;
  # OUTPUT_PIXELTYPE
  $content =~ s/\@OUTPUT_PIXELTYPE\@/$outputPixeltype/g;
  # NUM_PARAMETERS
  my $numParams = scalar @{$filterHash->{"Parameters"}};
  $content =~ s/\@NUM_PARAMETERS\@/$numParams/g;
  
  #----------mdlInitializeSizes function----------#
  # SETUP_SPECIAL_DATATYPE
  my $setupSpecialDatatypeString = setupSpecialDatatypeString($filterHash);
  $content =~ s/\@SETUP_SPECIAL_DATATYPE\@/$setupSpecialDatatypeString/g;
  # SETUP_INPUT_PORTS
  my $setupInputPortsString = setupInputPortsString($filterHash, $inputPixeltype);
  $content =~ s/\@SETUP_INPUT_PORTS\@/$setupInputPortsString/g;
  # SETUP_SPECIAL_INPUT_PORTS
  my $setupSpecialInputPortsString = setupSpecialInputPortsString($filterHash);
  $content =~ s/\@SETUP_SPECIAL_INPUT_PORTS\@/$setupSpecialInputPortsString/g;
  # SET_INPUT_PORTS_CONTIGUOUS
  my $setInputPortsContinguousString = setInputPortsContinguousString($filterHash);
  $content =~ s/\@SET_INPUT_PORTS_CONTIGUOUS\@/$setInputPortsContinguousString/g;
  # SET_INPUT_PORTS_DIRECT_FEEDTHROUGH
  my $setInputPortsDirectFeedthroughString = setInputPortsDirectFeedthroughString($filterHash);
  $content =~ s/\@SET_INPUT_PORTS_DIRECT_FEEDTHROUGH\@/$setInputPortsDirectFeedthroughString/g;
  # SETUP_OUTPUT_PORTS 
  my $setupOutputPortsString = setupOutputPortsString($filterHash, $outputPixeltype);
  $content =~ s/\@SETUP_OUTPUT_PORTS\@/$setupOutputPortsString/g;
  
  #----------mdlOutputs function----------#
  # GET_PARAMETER_VALUES
  my $getParameterValuesString = getParameterValuesString($filterHash);
  $content =~ s/\@GET_PARAMETER_VALUES\@/$getParameterValuesString/g;
  # SET_PARAMETER_VALUES
  my $setParameterValuesString = setParameterValuesString($filterHash);
  $content =~ s/\@SET_PARAMETER_VALUES\@/$setParameterValuesString/g;
  # GET_INPUT_PORT_SIGNALS
  my $getInputPortSignalsString = getInputPortSignalsString($filterHash, $inputPixeltype);
  $content =~ s/\@GET_INPUT_PORT_SIGNALS\@/$getInputPortSignalsString/g;
  # SET_FILTER_BLOCK_INPUT
  my $setFilterBlockInputString = setFilterBlockInputString($filterHash);
  $content =~ s/\@SET_FILTER_BLOCK_INPUT\@/$setFilterBlockInputString/g;
  ##SET_FILTER_BLOCK_SPECIAL_INPUTS
  my $setFilterBlockSpecialInputsString = setFilterBlockSpecialInputsString($filterHash);
  $content =~ s/\@SET_FILTER_BLOCK_SPECIAL_INPUTS\@/$setFilterBlockSpecialInputsString/g;
  # GET_OUTPUT_PORT_SIGNALS
  my $getOutputPortSignalsString = getOutputPortSignalsString($filterHash, $outputPixeltype);
  $content =~ s/\@GET_OUTPUT_PORT_SIGNALS\@/$getOutputPortSignalsString/g;
  # SET_FILTER_BLOCK_OUTPUT
  my $setFilterBlockOutputString = setFilterBlockOutputString($filterHash);
  $content =~ s/\@SET_FILTER_BLOCK_OUTPUT\@/$setFilterBlockOutputString/g;
  # UPDATE_OUTPUT_DATA_INFORMATION
  my $updateOutputDataInformationString = updateOutputDataInformationString($filterHash);
  $content =~ s/\@UPDATE_OUTPUT_DATA_INFORMATION\@/$updateOutputDataInformationString/g;
  
  
  print OUTFILE $content;
  close OUTFILE;
}

# Returns the Simulink datatype corresponding to a given C++ datatype
# Returns empty string for unrecognized C++ datatypes
sub simulinkDatatype {
  my $cppType = shift;
  switch ($cppType) {
    case "float" { return "SS_SINGLE"; }
    case "char" { return "SS_INT8"; }
    case "unsigned char" { return "SS_UINT8"; }
    case "short" { return "SS_INT16"; }
    case "unsigned short" { return "SS_UINT16"; }
    else    { return ""; }
  }
}

# Returns the Simulink datatype index corresponding to a given C++ datatype
# Returns empty string for unrecognized C++ datatypes
sub simulinkDatatypeIndex {
  my $simType = simulinkDatatype(shift);
  switch ($simType) {
    case "SS_DOUBLE" { return "0"; }
    case "SS_SINGLE" { return "1"; }
    case "SS_INT8" { return "2"; }
    case "SS_UINT8" { return "3"; }
    case "SS_INT16" { return "4"; }
    case "SS_UINT16" { return "5"; }
    case "SS_INT32" { return "6"; }
    case "SS_UINT32" { return "7"; }
    case "SS_BOOLEAN" { return "8"; }
    else    { return ""; }
  }
}

sub setupSpecialDatatypeString {
  my $filterHash = shift;
  my $string = "";
  
  if (scalar @{$filterHash->{"Special_Inputs"}} >= 1) {
    $string = $string .
      "\t//set up special datatype in Matlab which is a pointer to the container\n" .
      "\tDTypeId SpecialTypeID;\n" .
      "\n" .
      "\tif (ssGetDataTypeId((S), \"ITKSpecialType\") == INVALID_DTYPE_ID){\n" .
        "\t\tSpecialTypeID = ssRegisterDataType(S, \"ITKSpecialType\");\n" .
        "\t\tif (SpecialTypeID == INVALID_DTYPE_ID)    return;\n" .
        "\t\tint status = ssSetDataTypeSize(S, SpecialTypeID, sizeof(void *));\n" .
        "\t\tif (status == 0) return;\n" .
      "\t}\n" .
      "\telse{\n" .
        "\t\tSpecialTypeID = ssGetDataTypeId(S, \"ITKSpecialType\");\n" .
      "\t}";
  }
  return $string;
}

# Set up 2 input ports for every input image
sub setupInputPortsString {
  my ($filterHash, $inputPixeltype) = @_;
  my $numInputs = scalar @{$filterHash->{"Inputs"}};
  my $numSpecialInputs = scalar @{$filterHash->{"Special_Inputs"}};
  my $string = "";
  
  $string = $string .
    "\tif (!ssSetNumInputPorts(S, " . (2*$numInputs + $numSpecialInputs) . ")) return;\n\n";
  
  # Loop over each input image and setup two ports for each
  for (my $i = 0; $i < $numInputs; $i++) {

    # Set up a port for the image information
    my $portNum = $i*2;
    $string = $string .
      "\t//setup input port for image information\n" .
      "\tssSetInputPortDataType( S, " . $portNum . ", SS_DOUBLE);\n" .
      "\tssSetInputPortMatrixDimensions(S, " . $portNum . ", 2, IMAGE_DIMENSIONALITY);" .
      "\n\n";
    
    # Set up a port for the image data
    $string = $string . "\t//setup input port for image data\n";
    my $portNum = $i*2+1;
    my $dimsInfoName = "dimensionInfoInputPort" . $portNum;
    my $dimsName = "dimsInputPort" . $portNum;
      
    $string = $string .
      "\tDECL_AND_INIT_DIMSINFO(" . $dimsInfoName . ");\n" .
      "\t" . $dimsInfoName . ".numDims = DYNAMICALLY_SIZED;\n" .
      "\tint " . $dimsName . "[IMAGE_DIMENSIONALITY];\n" .
      "\tfor (int i=0; i<IMAGE_DIMENSIONALITY; i++) {\n" .
        "\t\t" . $dimsName . "[i] = DYNAMICALLY_SIZED;\n" .
      "\t}\n" .
      "\t" . $dimsInfoName . ".dims = " . $dimsName . ";\n" .
      "\t" . $dimsInfoName . ".width = DYNAMICALLY_SIZED;\n" .
      "\tssSetInputPortDimensionInfo(S, " . $portNum . ", &" . $dimsInfoName . ");\n" . 
      "\tssSetInputPortDataType( S, " . $portNum . ", " . simulinkDatatype($inputPixeltype) . ");" .
      "\n";
  }
  return $string;
}

sub setupSpecialInputPortsString {
  my $filterHash = shift;
  my $numSpecialInputs = scalar @{$filterHash->{"Special_Inputs"}};
  my $string = "";

  my $portNum = (scalar @{$filterHash->{"Inputs"}})*2;
  for (my $i = 0; $i < $numSpecialInputs; $i++) {
    $string = $string .
      "\t//setup input port for special type\n" .
      "\tssSetInputPortWidth(S, " . $portNum . ", 1);\n" .
      "\tssSetInputPortDataType(S, " . $portNum . ", SpecialTypeID);\n" .
      "\n";
    $portNum++;
  }
  return $string;
}

sub setInputPortsContinguousString {
  my $filterHash = shift;
  my $numInputs = scalar @{$filterHash->{"Inputs"}};
  my $numSpecialInputs = scalar @{$filterHash->{"Special_Inputs"}};
  my $string = "";
  
  for (my $i = 0; $i < $numInputs*2 + $numSpecialInputs; $i++) {
    $string = $string .
      "\tssSetInputPortRequiredContiguous(S, " . $i . ", true);\n";
  }
  return $string;
}

sub setInputPortsDirectFeedthroughString {
  my $filterHash = shift;
  my $numInputs = scalar @{$filterHash->{"Inputs"}};
  my $numSpecialInputs = scalar @{$filterHash->{"Special_Inputs"}};
  my $string = "";

  for (my $i = 0; $i < $numInputs*2 + $numSpecialInputs; $i++) {
    $string = $string .
      "\tssSetInputPortDirectFeedThrough(S, " . $i . ", 1);\n";
  }
  return $string;
}

sub setupOutputPortsString {
  my ($filterHash, $outputPixeltype) = @_;
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $string = "";

  $string = $string .
    "\tif (!ssSetNumOutputPorts(S, " . (2*$numOutputs) . ")) return;\n\n";
  
  # Loop over each output image and setup two ports for each
  for (my $i = 0; $i < $numOutputs; $i++) {
  
    # Set up a port for the image information
    $string = $string . "\t//setup output port for image information\n";
    my $portNum = $i*2;
    my $dimsInfoName = "dimensionInfoOutputPort" . $portNum;
    my $dimsName = "dimsOutputPort" . $portNum;
   
    $string = $string .
      "\tDECL_AND_INIT_DIMSINFO(" . $dimsInfoName . ");\n" .
      "\t" . $dimsInfoName . ".numDims = 2;\n" .
      "\tint " . $dimsName . "[2];\n" .
      "\t" . $dimsName . "[0] = 2;\n" .
      "\t" . $dimsName . "[1] = IMAGE_DIMENSIONALITY;\n" .
      "\t" . $dimsInfoName . ".dims = " . $dimsName . ";\n" .
      "\t" . $dimsInfoName . ".width = 2*IMAGE_DIMENSIONALITY;\n" .
      "\tssSetOutputPortDimensionInfo(S, " . $portNum . ", &" . $dimsInfoName . ");\n" . 
      "\tssSetOutputPortDataType( S, " . $portNum . ", SS_DOUBLE);\n\n";
      
    # Set up a port for the image information
    $string = $string . "\t//setup output port for image data\n";
    my $portNum = $i*2+1;
    my $dimsInfoName = "dimensionInfoOutputPort" . $portNum;
    my $dimsName = "dimsOutputPort" . $portNum;
   
    $string = $string .
      "\tDECL_AND_INIT_DIMSINFO(" . $dimsInfoName . ");\n" .
      "\t" . $dimsInfoName . ".numDims = DYNAMICALLY_SIZED;\n" .
      "\tint " . $dimsName . "[IMAGE_DIMENSIONALITY];\n" .
      "\tfor (int i=0; i<IMAGE_DIMENSIONALITY; i++) {\n" .
        "\t\t" . $dimsName . "[i] = DYNAMICALLY_SIZED;\n" .
      "\t}\n" .
      "\t" . $dimsInfoName . ".dims = " . $dimsName . ";\n" .
      "\t" . $dimsInfoName . ".width = DYNAMICALLY_SIZED;\n" .
      "\tssSetOutputPortDimensionInfo(S, " . $portNum . ", &" . $dimsInfoName . ");\n" . 
      "\tssSetOutputPortDataType( S, " . $portNum . ", " . simulinkDatatype($outputPixeltype) . ");";
  }
  return $string;  
}

sub getParameterValuesString {
  my $filterHash = shift;
  my $numParams= scalar @{$filterHash->{"Parameters"}};
  my $string = "";
  
  # Loop over each parameter
  for (my $i = 0; $i < $numParams; $i++) {
    my $param = $filterHash->{"Parameters"}->[$i];
    my $paramType = $param->{"Parameter_Type"};
    my $paramSize = $param->{"Parameter_Size"};
    
    $string = $string . "\t";
    
    # If the datatype is an ITK or Enum parameter type, the parameter will always be stored in a double. This will
    # be turned into a pointer to a double if the parameter is found to be not scalar (likely the case).
    if ($param->{"ITK_Parameter_Type"} ne "" ||
      $param->{"Enum_Parameter_Type"} ne "") {
      $string = $string . "double";
    }
    else {
      # TODO: Assumes there is only one type of input image pixeltype
      if (isInputPixelType($paramType, $filterHash)) {
        $string = $string . "INPUT_IMAGE_PIXELTYPE";    
      }
      # TODO: Assumes there is only one type of output image pixeltype
      elsif (isOutputPixelType($paramType, $filterHash)) {
        $string = $string . "OUTPUT_IMAGE_PIXELTYPE";    
      }
      else {
        $string = $string . $paramType;
      }
    }
    
    # Convert the datatype to a datatype pointer if the parameter is not scalar
    if ($paramSize ne "1,1") {
      $string = $string . "*";
    }
    
    $string = $string . " " . $param->{"Parameter_Name"} . "=" .
      "mxGetPr(ssGetSFcnParam(S," . $i . "))";
    if ($paramSize eq "1,1") {
      $string = $string . "[0]";
    }
    $string = $string . ";\n";
  }
  return $string;
}

# Returns true if 'datatype' is equal to any of the input image types stored in 'filterHash'
sub isInputPixelType {
  my ($datatype, $filterHash) = @_;
  
  foreach my $input ( @{$filterHash->{"Inputs"}} ) {
    if ($datatype eq $input->{"Input_Type"}) {
      return 1;
    }
  }
  return 0;
}

# Returns true if 'datatype' is equal to any of the output image types stored in 'filterHash'
sub isOutputPixelType {
  my ($datatype, $filterHash) = @_;
  
  foreach my $output ( @{$filterHash->{"Outputs"}} ) {
    if ($datatype eq $output->{"Output_Type"}) {
      return 1;
    }
  }
  return 0;
}

sub setParameterValuesString {
  my $filterHash = shift;
  my $string = "";
  
  foreach my $param ( @{$filterHash->{"Parameters"}} ) {
    my $paramName = $param->{"Parameter_Name"};
    $string = $string . "\tfilter->Set" . $paramName . "(" . $paramName .
      ");\n";
  }
  return $string;
}

sub getInputPortSignalsString {
  my ($filterHash, $inputPixeltype) = @_;
  my $numInputs = scalar @{$filterHash->{"Inputs"}};
  my $string = "";

  for (my $i = 0; $i < $numInputs; $i++) {
    my $inputName = $filterHash->{"Inputs"}->[$i]->{"Input_Name"};
    
    # Get signal containing input origin and spacing from the image information port
    $string = $string .
      "\t// Get signal containing input origin and spacing from image information port\n" .
      "\tdouble *" . $inputName . "OriginAndSpacing = (double*) " .
        "ssGetInputPortSignal(S," . ($i*2) . ");\n" .
      "\tdouble " . $inputName . "Origin[IMAGE_DIMENSIONALITY];\n" .
      "\tdouble " . $inputName . "Spacing[IMAGE_DIMENSIONALITY];\n" .
      "\tfor (int i=0; i<IMAGE_DIMENSIONALITY; i++) {\n" .
        "\t\t" . $inputName ."Origin[i] = " . $inputName . "OriginAndSpacing[i];\n" .
        "\t\t" . $inputName . "Spacing[i] = " . 
          $inputName . "OriginAndSpacing[i+IMAGE_DIMENSIONALITY];\n" .
      "\t}\n\n";
      
    # Get signal from image data port
    $string = $string .
      "\t// Get signal from image data port and cast to correct type\n" .
      "\tINPUT_IMAGE_PIXELTYPE* " . $inputName . "PortMatrix = (INPUT_IMAGE_PIXELTYPE*) " .
        "ssGetInputPortSignal(S," . ($i*2+1) . ");\n\n";
        
    # Get input size info from the input data itself
    $string = $string .
      "\t// Get input size info from the input data itself\n" .
      "\t// To avoid type cast to the pointer, we are copying to an unsigned int array\n" .
      "\tunsigned int " . $inputName . "Size[IMAGE_DIMENSIONALITY];\n" .
      "\tint* " . $inputName . "SizeInt = ssGetInputPortDimensions(S," . ($i*2+1) . ");\n" .
      "\tfor(int i=0; i<IMAGE_DIMENSIONALITY; i++){\n" .
        "\t\t" . $inputName . "Size[i] = " . $inputName . "SizeInt[i];\n" .
      "\t}\n\n";
      
    # Make sure the input image type is valid
    # We are assuming ONE pixeltype type represents ALL input image types
    $string = $string .
      "\t// Make sure the input image type is valid\n" . 
      "\tif(ssGetInputPortDataType(S, " . ($i*2+1) . ") != " .
        simulinkDatatypeIndex($inputPixeltype) . "){ // " . simulinkDatatypeIndex($inputPixeltype) . 
        " is " . $inputPixeltype . "\n" .
        "\t\tssSetErrorStatus(S,\"Invalid Image Type.\");\n" .
        "\t\treturn;\n" .
      "\t}";
  }
  return $string;
}

sub setFilterBlockInputString {
  my $filterHash = shift;
  my $numInputs = scalar @{$filterHash->{"Inputs"}};
  my $string = "";
  
  for (my $i = 0; $i < $numInputs; $i++) {
    my $inputName = $filterHash->{"Inputs"}->[$i]->{"Input_Name"};
    $string = $string . 
      "\tfilter->GetInput(" . $i . ").SetArray(" . $inputName . "PortMatrix);\n" .
      "\tfilter->GetInput(" . $i . ").SetSize(" . $inputName . "Size);\n" .
      "\tfilter->GetInput(" . $i . ").SetOrigin(" . $inputName . "Origin);\n" .
      "\tfilter->GetInput(" . $i . ").SetSpacing(" . $inputName . "Spacing);\n";
  }
  return $string;
}

sub setFilterBlockSpecialInputsString {
  my $filterHash = shift;
  my $numSpecialInputs = scalar @{$filterHash->{"Special_Inputs"}};
  my $string = "";
  
  my $portNum = (scalar @{$filterHash->{"Inputs"}})*2;
  for (my $i = 0; $i < $numSpecialInputs; $i++) {
    $string = $string .
      "\t//Get value from input port which is a pointer to a special ITK type\n" .
      "\tvoid** SpecialInputPointer" . $i . " = (void**) ssGetInputPortSignal(S," . $portNum .");\n" .
      "\tfilter->GetSpecialInput(" . $i . ").SetPointer(SpecialInputPointer" . $i . "[0]);\n\n";
    $portNum++;
  }
  return $string;
}

sub getOutputPortSignalsString {
  my ($filterHash, $outputPixeltype) = @_;
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $string = "";

  for (my $i = 0; $i < $numOutputs; $i++) {
    my $outputName = $filterHash->{"Outputs"}->[$i]->{"Output_Name"};
    
    # Get signal containing output origin and spacing from the image information port
    $string = $string .
      "\t// Get signal containing output origin and spacing from image information port\n" .
      "\tdouble *" . $outputName . "OriginAndSpacing = (double*) " .
        "ssGetOutputPortSignal(S," . ($i*2) . ");\n\n";
      
    # Get signal from image data port
    $string = $string .
      "\t// Get signal from image data port and cast to correct type\n" .
      "\tOUTPUT_IMAGE_PIXELTYPE* " . $outputName . "PortMatrix = (OUTPUT_IMAGE_PIXELTYPE*) " .
        "ssGetOutputPortSignal(S," . ($i*2+1) . ");\n\n";
        
    # Get output size info from the output data itself
    $string = $string .
      "\t// Get output size info from the output data itself\n" .
      "\t// To avoid type cast to the pointer, we are copying to an unsigned int array\n" .
      "\tunsigned int " . $outputName . "Size[IMAGE_DIMENSIONALITY];\n" .
      "\tint* " . $outputName . "SizeInt = ssGetOutputPortDimensions(S," . ($i*2+1) . ");\n" .
      "\tfor(int i=0; i<IMAGE_DIMENSIONALITY; i++){\n" .
        "\t\t" . $outputName . "Size[i] = " . $outputName . "SizeInt[i];\n" .
      "\t}\n\n";
      
    # Make sure the output image type is valid
    # TODO:  we are assuming ONE pixeltype type represents ALL output image types
    $string = $string .
      "\t// Make sure the output image type is valid\n" . 
      "\tif (ssGetOutputPortDataType(S, " . ($i*2+1) . ") != " .
        simulinkDatatypeIndex($outputPixeltype) . "){ // " . simulinkDatatypeIndex($outputPixeltype) . 
        " is " . $outputPixeltype . "\n" .
        "\t\tssSetErrorStatus(S,\"Invalid Image Type.\");\n" .
        "\t\treturn;\n" .
      "\t}";
  }
  return $string;
}

sub setFilterBlockOutputString {
  my $filterHash = shift;
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $string = "";
  
  for (my $i = 0; $i < $numOutputs; $i++) {
    my $outputName = $filterHash->{"Outputs"}->[$i]->{"Output_Name"};
    $string = $string . 
      "\tfilter->GetOutput(" . $i . ").SetArray(" . $outputName . "PortMatrix);\n" .
      "\tfilter->GetOutput(" . $i . ").SetSize(" . $outputName . "Size);";
  }
  return $string;
}

sub updateOutputDataInformationString {
  my $filterHash = shift;
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $string = "";
  
  for (my $i = 0; $i < $numOutputs; $i++) {
    my $outputName = $filterHash->{"Outputs"}->[$i]->{"Output_Name"};
    $string = $string .
      "\tdouble *" .$outputName. "UpdatedOrigin = filter->GetOutput(" .$i. ").GetOrigin();\n" .
      "\tdouble *" .$outputName. "UpdatedSpacing = filter->GetOutput(" .$i. ").GetSpacing();\n" .
      "\n" .
      "\tfor(int i=0; i < IMAGE_DIMENSIONALITY; i++){\n" .
        "\t\t" .$outputName. "OriginAndSpacing[i] = " .$outputName. "UpdatedOrigin[i];\n" .
        "\t\t" .$outputName. "OriginAndSpacing[i+IMAGE_DIMENSIONALITY] = " .$outputName. "UpdatedSpacing[i];\n" .
      "\t}\n";
  }
  return $string;
}

1;

