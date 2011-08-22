package vtkSFunctionGen;


# =================
# Copyright (c) Queen's University
# All rights reserved.

# See Copyright.txt for more details.
# =================

###############################################
# SIMITK Project
# Karen Li and Jing Xiang
# February 20, 2008
#
# Modified by Adam Campigotto on June 10th 2008
# to be used with VTK
###############################################

use strict;
use Switch;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(vtkSFunctionGen);

# Generates S-Function file.
# Inputs: 1. filterHash reference
#	      2. directory
sub vtkSFunctionGen {

  my ($filterHash, $directory, $algorithmSubclassesHash, $sourceDirectory, $buildDirectory) = @_;
  
  die "ERROR: SimvtkTemplate.cpp.in file not found"
  unless -f $sourceDirectory . "/SimvtkTemplate.cpp.in";
  # Read the input file into a single string
  open (INFILE, "<", $sourceDirectory . "/SimvtkTemplate.cpp.in");
  undef $/;
  my $content = <INFILE>;
  
  $/ = "\n";
  close INFILE;
  
  # if is not on Windows, remove the control-M characters
  if ($^O ne "MSWin32") {
    $content =~ s/\r//g;
  }
  
  # Create the output file
  open (OUTFILE, ">$buildDirectory/Sim" . $filterHash->{"Filter_Name"} . "Mat.cpp");
  
  # Fix headers for Linux systems for vtkRenderWindowInteractor
  my $newHeader = "";
 
  if ($algorithmSubclassesHash->{$filterHash->{"Filter_Name"}})
  {
    $newHeader .= "\n#include \"vtkInformation.h\"\n";
  }
  
  if (($^O eq "linux") && ($filterHash->{"Filter_Name"} =~ /RenderWindowInteractor$/)) {
    $newHeader .= setupLinuxHeader();
  }
  $content =~ s/\@LINUX_HEADER\@/$newHeader/g;
  
  
  # FILTER_NAME
  $content =~ s/\@FILTER_NAME\@/$filterHash->{"Filter_Name"}/g;
  
  #NUM_INPUTS
  my $numInputs = 0;
  $numInputs = scalar @{$filterHash->{"Inputs"}} if $filterHash->{"Inputs"};
  $content =~ s/\@NUM_INPUTS\@/$numInputs/g;
  
  #NUM_OUTPUTS
  my $numOutputs = 0;
  $numOutputs = scalar @{$filterHash->{"Outputs"}} if $filterHash->{"Outputs"};
  $content =~ s/\@NUM_OUTPUTS\@/$numOutputs/g;
  
  # NUM_PARAMETERS
  my $numParams = 0;
  $numParams = scalar @{$filterHash->{"Filter_Parameters"}} if $filterHash->{"Filter_Parameters"};
  $content =~ s/\@NUM_PARAMETERS\@/$numParams/g;
  
  #NUM_INPUTS + PARAMETERS
  #CHANGE HERE! (3 to 2)
  my $numInputsAndParameters = $numParams * 2 + $numInputs;
  $content =~ s/\@NUM_INPUTS_PARAMETERS\@/$numInputsAndParameters/g;
  
  #NUM_INPUTS_PARAMETERS_OUTPUTS
  #CHANGE HERE! (3 to 2)
  my $numInAndParametersAndOut = $numParams * 2 + $numInputs + $numOutputs;
  $content =~ s/\@NUM_INPUTS_PARAMETERS_OUTPUTS\@/$numInAndParametersAndOut/g;
  
    #ALGORITHM_STRINGS
  my $algorithmInitializeSizes = "";
  my $algorithmStartInputString = "";
  my $algorithmStartOutputString = "";
  my $algorithmUpdateInputString = "";
  my $algorithmUpdateOutputString = "";
  if ($algorithmSubclassesHash->{$filterHash->{"Filter_Name"}})
  {
  $algorithmInitializeSizes = setupAlgorithmInitializeSizesString($filterHash);
  $algorithmStartInputString = setupAlgorithmStartInputString();
  $algorithmStartOutputString = setupAlgorithmStartOutputString();
  $algorithmUpdateInputString = setupAlgorithmUpdateInputString();
  $algorithmUpdateOutputString = setupAlgorithmUpdateOutputString();
  }
  $content =~ s/\@ALGORITHM_INITIALIZE_SIZES\@/$algorithmInitializeSizes/g;
  $content =~ s/\@ALGORITHM_START_INPUT\@/$algorithmStartInputString/g;
  $content =~ s/\@ALGORITHM_START_OUTPUT\@/$algorithmStartOutputString/g;
  $content =~ s/\@ALGORITHM_UPDATE_INPUTS\@/$algorithmUpdateInputString/g;
  $content =~ s/\@ALGORITHM_UPDATE_OUTPUTS\@/$algorithmUpdateOutputString/g;
  
  #----------mdlInitializeSizes function----------#

  # SETUP_INPUT_PORTS
  
  my %sizesHash = ();
  my $dynamic = setupParameterSizeHash($filterHash, $numInputs, \%sizesHash);
  $content =~ s/\@DYNAMIC\@/$dynamic/g;
  my $setupInputArraySizesString = setupInputArraySizesString($filterHash, \%sizesHash) if (scalar @{$filterHash->{"Filter_Parameters"}} > 0);
  $content =~ s/\@INPUT_ARRAY_SIZES\@/$setupInputArraySizesString/g;
  my $setupOutputArraySizesString = setupOutputArraySizesString($filterHash, \%sizesHash) if (scalar @{$filterHash->{"Filter_Parameters"}} > 0);
  $content =~ s/\@OUTPUT_ARRAY_SIZES\@/$setupOutputArraySizesString/g;
  
  my %typesHash = ();
  setupParameterTypeHash($filterHash, $numInputs, \%typesHash);
  my $setupInputArrayTypesString = setupInputArrayTypesString($filterHash, \%typesHash) if (scalar @{$filterHash->{"Filter_Parameters"}} > 0);
  $content =~ s/\@INPUT_ARRAY_TYPES\@/$setupInputArrayTypesString/g;
  my $setupOutputArrayTypesString = setupOutputArrayTypesString($filterHash, \%typesHash) if (scalar @{$filterHash->{"Filter_Parameters"}} > 0);
  $content =~ s/\@OUTPUT_ARRAY_TYPES\@/$setupOutputArrayTypesString/g;
  
  #----------mdlStart function-------------#
  #SET_INPUTS
   my $index = 0;
  my $selfInputLocation = 1;
  my $setupProcessInputString = setupProcessInputString($filterHash, \$index, \$selfInputLocation);
  $content =~ s/\@SELF_INPUT_LOCATION\@/$selfInputLocation/g;
  $content =~ s/\@PROCESS_INPUT\@/$setupProcessInputString/g;
  #SET_PARAMETERS
  my $setupProcessParameterStartString = setupProcessParameterStartString($filterHash, \$index);
  $content =~ s/\@PROCESS_PARAMETERS_START\@/$setupProcessParameterStartString/g;
  #SET_OUTPUT
  my $setupProcessOutputString = setupProcessOutputString($filterHash, \$index);
  $content =~ s/\@PROCESS_OUTPUT\@/$setupProcessOutputString/g;
  
  
  #----------mdlOutputs function----------#
  # SET_PARAMETERS
  my $setupProcessParameterOutputString = setupProcessParameterOutputString($filterHash);
  $content =~ s/\@PROCESS_PARAMETERS_OUTPUT\@/$setupProcessParameterOutputString/g;
  
  #RENDER_WINDOW
  my $filterType = "";
  my $filterName = $filterHash->{"Filter_Name"};
  if ($filterName =~ /RenderWindow$/)
  {
  $filterType = "  if (filter->GetInteractor() == 0) { filter->Render(); }\n";
  }
  if ($filterName =~ /ImageViewer$/ || $filterName =~ /ImageViewer2$/ )
  {
  $filterType = "  filter->Render();\n";
  }
  if ($filterName =~ /Writer$/ || $filterName =~ /Writer2$/ )
  {
  $filterType = "  filter->Write();\n";
  }
  $content =~ s/\@RENDER_WINDOW\@/$filterType/g;
  $filterType = "";
  if ($filterName =~ /RenderWindowInteractor$/)
  {
  $filterType = setupInitialize($filterName);
  }
  $content =~ s/\@RENDER_WINDOW_INTERACTOR\@/$filterType/g;
  
  
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
  case "double" { return "SS_DOUBLE"; }
  case "int" { return "SS_INT32"; }
  case "unsigned int" { return "SS_UINT32"; }
  case "unsigned long" { return "SS_UINT32"; }
  case "bool" { return "SS_BOOLEAN"; }
  else	{ return ""; }
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
  else	{ return ""; }
  }
}

##########################################################
#setupLinuxHeader
# string that will include necessary files for RenderWindowInteractor on Linux
##########################################################
sub setupLinuxHeader{
  my $string = "";
  
  $string = "#include \"vtkXRenderWindowInteractor.h\"\n" .
  "#include <X11/X.h>\n" .
  "#include <X11/Shell.h>\n";
  return $string;
}

##########################################################
#setupAlgorithmInitializeSizesString
# string that will get number of input and output types of a vtkObject related to input and output ports
##########################################################
sub setupAlgorithmInitializeSizesString{
  my $filterHash = shift;
  my $string = "";
  
  my $filterName = $filterHash->{"Filter_Name"};
  
  $string = $string . "  " . $filterName . " *temporary = " . $filterName . "::New();\n" .
    "  nRealInputPorts += temporary->GetNumberOfInputPorts();\n" .
    "  nOutputPorts += temporary->GetNumberOfOutputPorts();\n" .
    "  for (i = 0; i < nRealInputPorts; i++)\n" . 
    "    {\n" .
    "    if (temporary->GetInputPortInformation(i)->\n" .
    "       Get(vtkAlgorithm::INPUT_IS_OPTIONAL()))\n" .
    "      {\n" .
    "      nRealInputPorts = i;\n" .
    "      break;\n" .
    "      }\n" .
    "    }\n" .
    "  temporary->Delete();\n" ;

  return $string;
}


##########################################################
#setupAlgorithmStartInputString
# string that will be used to set up input ports of algorithm
##########################################################
sub setupAlgorithmStartInputString{
  my $string = "";
  
  $string = $string . "  vtkAlgorithmOutput **nextInput;\n" . 
    "  for (i = 0; i <filter->GetNumberOfInputPorts() && ssGetInputPortConnected(S, i); i++)\n" .
    "  {\n" .
    "    void *point = const_cast<void*>(ssGetInputPortSignal(S,i));\n" .
    "    nextInput = reinterpret_cast<vtkAlgorithmOutput**>(point);\n" .
    "    filter->SetInputConnection(i, nextInput[0]);\n" .
    "  }\n";
    
  return $string;
}

##########################################################
#setupAlgorithmStartOutputString
# string that will be used to set up output ports of algorithm
##########################################################
sub setupAlgorithmStartOutputString{
  my $string = "";
  
  $string = $string . "  for (i = 0; i <filter->GetNumberOfOutputPorts() && ssGetOutputPortConnected(S, outputPortIndex); i++)\n" .
    "  {\n" .
    "    vtkAlgorithmOutput **OutputPort;\n" .
    "    OutputPort = reinterpret_cast<vtkAlgorithmOutput**>(ssGetOutputPortSignal(S,outputPortIndex));\n" .
    "    OutputPort[0] =  filter->GetOutputPort(i);\n" .
    "    outputPortIndex++;\n" .
    "  }\n" ;
    
  return $string;
}

##########################################################
#setupAlgorithmUpdateInputString
# string that will be used to set update input port number in MDL outputs
##########################################################
sub setupAlgorithmUpdateInputString{
  my $string = "";
  
  $string = $string . "  inputPortIndex += filter->GetNumberOfInputPorts();\n" ;
    
  return $string;
}

##########################################################
#setupAlgorithmUpdateOutputString
# string that will be used to set update output port number in MDL Outputs
##########################################################
sub setupAlgorithmUpdateOutputString{
  my $string = "";
  
  $string = $string . "  outputPortIndex += filter->GetNumberOfOutputPorts();\n" ;
    
  return $string;
}

##########################################################
#setupParameterSizeHash
# will list the start position for the triplet of (input indicator, output indicator, parameter) in the S-function
# parameter list.  (so if need input indicator will return that value, if want output indicator will have to
# add one to stored value and if want parameter location must add 2 to the stored value.  Stores the 
# parameters with common data type in an array in a hash.
##########################################################
sub setupParameterSizeHash{
  my ($filterHash, $numInputs, $sizesHash) = @_;
  my $count = $numInputs;
  my $dynamic = "#undef";
  
  foreach my $param (@{$filterHash->{"Filter_Parameters"}} )
    {
        my $paramSize = $param->{"Parameter_Size"};
        push (@{$sizesHash->{$paramSize}}, $count);
        $dynamic = "#define" if ($paramSize eq "N");
        #CHANGE HERE! (3 to 2)
        $count += 2;
    }
  return $dynamic;
}

##########################################################
# setupInputArraySizesString
#Set up array dimensionality for parameters that will be promoted inputs
##########################################################
sub setupInputArraySizesString {
  my ($filterHash, $sizesHash) = @_;
  my $casesStrings = "";
 
  $casesStrings = $casesStrings . "  for (i = ParameterListInputPortEndLocation; i < ParameterListOutputPortStartLocation" .
  #CHANGE HERE! (change the +3 to +2)
    " && InputPortIndex < ssGetNumInputPorts(S); i = i + 2) //because want to skip actual value\n" .
    "  {\n" . 
    "    if(static_cast<int>(mxGetScalar(ssGetSFcnParam(S,i))) == 2) \n" .
    "    {\n" .
    "      switch(i) //divide items based on size of array\n" .
    "      {\n";
  
  foreach my $size (keys %$sizesHash)
  {
    $casesStrings = $casesStrings . "      "; #make sure proper indentation
    foreach my $case (@{$sizesHash->{$size}})
    {
      $casesStrings = $casesStrings . "case " . $case . ": "; # make all the right cases for one size
    }
    $casesStrings = $casesStrings . "\n        ssSetInputPortWidth(S, InputPortIndex, ";
    if ($size == "N")
    {
      $casesStrings .= "DYNAMICALLY_SIZED";
    }
    else 
    {
      $casesStrings .= $size;
    }
    $casesStrings = $casesStrings . ");\n        break;\n";
  }

  $casesStrings = $casesStrings . "      }\n";
  return $casesStrings;
}

##########################################################
# setupOutputArraySizesString
#Set up array dimensionality for parameters that will be promoted outputs
##########################################################
sub setupOutputArraySizesString {
  my ($filterHash, $sizesHash) = @_;
  my $casesStrings = "";
  
  #CHANGE HERE! (remove the +1 in start, the +3 in end of for loop, and the == 1 to == 4)
  $casesStrings = $casesStrings . "  for (i = ParameterListInputPortEndLocation; i < ParameterListOutputPortStartLocation" .
    " && OutputPortIndex < ssGetNumOutputPorts(S); i = i + 2) //because want to skip actual value\n" .
    "  {\n" . 
    "    if(static_cast<int>(mxGetScalar(ssGetSFcnParam(S,i))) == 4) \n" .
    "    {\n" .
    "      switch(i) //divide items based on size of array\n" .
    "      {\n";
  
  foreach my $size (keys %$sizesHash)
  {
    $casesStrings = $casesStrings . "      "; #make sure proper indentation
    foreach my $case (@{$sizesHash->{$size}})
    {
    #CHANGE HERE! (remove the +1 )
      $casesStrings = $casesStrings . "case " . $case . ": "; # make all the right cases for one size
    }
    $casesStrings = $casesStrings . "\n        ssSetOutputPortWidth(S, OutputPortIndex, ";
    if ($size == "N")
    {
      $casesStrings .= "DYNAMICALLY_SIZED";
    }
    else 
    {
      $casesStrings .= $size;
    }
    $casesStrings = $casesStrings . ");\n        break;\n";
  }
  
  $casesStrings = $casesStrings . "      }\n";
  return $casesStrings;
}

##########################################################
#setupParameterTypeHash
# will list the start position for the triplet of (input indicator, output indicator, parameter) in the S-function
# parameter list.  (so if need input indicator will return that value, if want output indicator will have to
# add one to stored value and if want parameter location must add 2 to the stored value.  Stores the 
# parameters with common data type in an array in a hash.
##########################################################
sub setupParameterTypeHash{
  my ($filterHash, $numInputs, $typesHash) = @_;
  my $count = $numInputs;
  
  foreach my $param (@{$filterHash->{"Filter_Parameters"}} )
    {
        my $paramType = $param->{"Parameter_Type"};
        push (@{$typesHash->{$paramType}}, $count);
        #CHANGE HERE! (3 to 2)
        $count += 2;
    }
}


##########################################################
# setupInputArrayTypesString
#Set up array type for parameters
##########################################################
sub setupInputArrayTypesString {
  my ($filterHash, $typesHash) = @_;
  my $casesStrings = "";
  
  $casesStrings = $casesStrings . "      switch(i) // divide items based on type of input\n" .
  "      {\n";
  foreach my $type (keys %$typesHash)
  {
    $casesStrings = $casesStrings . "      "; #make sure proper indentation
    foreach my $case (@{$typesHash->{$type}})
    {
      $casesStrings = $casesStrings . "case " . $case . ": "; # make all the right cases for one size
    }
    $casesStrings = $casesStrings . "\n        ssSetInputPortDataType(S, InputPortIndex, " . simulinkDatatype($type) . ");\n";
    $casesStrings = $casesStrings . "        break;\n";
  }
  
  $casesStrings = $casesStrings . "      }\n" .
    "      ssSetInputPortDirectFeedThrough(S, InputPortIndex, needsInput);\n" .
    "      ssSetInputPortRequiredContiguous(S, InputPortIndex, 1); //make all required contiguous\n" .
    "      InputPortIndex++;\n" .
    "    }\n" . 
    "  }\n";
  return $casesStrings;
}


##########################################################
# setupOutputArrayTypesString
#Set up array type for parameters that were promoted to outputs
##########################################################
sub setupOutputArrayTypesString {
  my ($filterHash, $typesHash) = @_;
  my $casesStrings = "";
  
  $casesStrings = $casesStrings . "      switch(i) // divide items based on type of input\n" .
  "      {\n";
  
  foreach my $type (keys %$typesHash)
  {
    $casesStrings = $casesStrings . "      "; #make sure proper indentation
    foreach my $case (@{$typesHash->{$type}})
    {
    #CHANGE HERE! ($case +1 should be $case)
      $casesStrings = $casesStrings . "case " . $case  . ": "; # make all the right cases for one size
    }
    $casesStrings = $casesStrings . "\n        ssSetOutputPortDataType(S, OutputPortIndex, " . simulinkDatatype($type) . ");\n";
    $casesStrings = $casesStrings . "        break;\n";
  }
  
  $casesStrings = $casesStrings . "      }\n" .
    "      OutputPortIndex++;\n" .
    "    }\n" . 
    "  }\n";
  return $casesStrings;
}

###########################################################
# setupProcessInputString
# process the inputs of all input ports
###########################################################
sub setupProcessInputString{
  my ($filterHash, $index, $selfInputLocation) = @_;
  my $inputString = "";
  
  foreach my $input (@{$filterHash->{"Inputs"}})
  {
    my $inputFlags = $input->{"Input_Flags"};
    my $inputType = $input->{"Input_Type"};
    my $inputName = $input->{"Input_Name"};
    if ($inputName eq "Self"){
      $$selfInputLocation = $$index;
    }
    else {
      if ($inputFlags eq "Repeatable,Optional")
      {
        $inputString = $inputString . "      for (j = 0; j < static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $$index . "))) && ssGetInputPortConnected(S,inputPortIndex); j++)\n"
      }
      else 
      {
        $inputString = $inputString . "      if (static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $$index . "))) == 1 && ssGetInputPortConnected(S, inputPortIndex))\n";
      }
      $inputString = $inputString . "        {\n" .
      "          void* point = const_cast<void*>(ssGetInputPortSignal(S, inputPortIndex));\n" .
      "          vtkObject *o = reinterpret_cast<vtkObject **>(point)[0] ;\n" .
      "          int typeIsCorrect = o->IsA(\"" . $inputType . "\");\n";

      # if inputType ends in "Data", check for vtkAlgorithmOutput
      if ($inputType =~ /Data$/)
      {
      $inputString = $inputString .
      "          if (!typeIsCorrect && o->IsA(\"vtkAlgorithmOutput\"))\n" .
      "          {\n" .
      "            vtkAlgorithmOutput *ao = static_cast<vtkAlgorithmOutput *>(o);\n" .

      "            o = ao->GetProducer()->GetOutputDataObject(ao->GetIndex());\n" .
      "            typeIsCorrect = o->IsA(\"" . $inputType . "\");\n" .
      "          }\n";
      }

      $inputString = $inputString .
      "          if (typeIsCorrect)\n" .
      "          {\n" .
      "            filter->";
      if ($inputFlags eq "Repeatable,Optional")
      {
        $inputString .= "Add";
      }
      else 
      {
        $inputString .= "Set";
      }
      $inputString = $inputString . $inputName . "(reinterpret_cast<" . $inputType . "*>(o));\n" .
      "          }\n" .
      "          else\n" .
      "          {\n" .
      "            ssSetErrorStatus(S, \"Bad input type: needs " . $inputType . "\");\n" .
      "          }\n" .
      "          inputPortIndex++;\n" .
      "        }\n" ;
    }
    $$index++;
  }
  return $inputString;
}

#########################################################################
# setupProcessParameterStartString
# sets up the string for the parameters in the mdlStart Simulink function for those parameters that stay parameters
#########################################################################
sub setupProcessParameterStartString{
  my ($filterHash, $index) = @_;
  my $string = "";
  
  foreach my $param (@{$filterHash->{"Filter_Parameters"}})
  {
    my $paramName = $param->{"Parameter_Name"};
    my $paramSize = $param->{"Parameter_Size"};
    my $paramType = $param->{"Parameter_Type"};

    $string .= "      if (static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $$index . "))) == 1)\n" .
    "      {\n";
    if ($paramType eq "char")
    {
      $string .= setupCharParameterStartString($paramName, $paramSize, $paramType, $index);
    }
    else
    {
      $string .= setupNumericParameterStartString($paramName, $paramSize, $paramType, $index);
    }
    $string .= "      }\n" ;
    #CHANGE HERE! (3 to 2)
    $$index = $$index + 2;
  }
  return $string;
}

##########################################################################
# setupNumericParameterStartString
# setup strings for all parameters that are of any numeric type (ie. not chars)
##########################################################################
sub setupNumericParameterStartString{
  my ($name, $size, $type, $index) = @_;
  my $string = "";
  
  if ($size != 1)
  {
  #CHANGE HERE! ( +2 to +1)
    $string = $string .
    "        double *arr = (double *)mxGetPr(ssGetSFcnParam(S, " . $$index . " + 1));\n";
  }
  
  $string = $string . "        filter->Set" . $name . "(";
  if ($size != 1)
  {
    for (my $i = 0; $i < $size; $i++)
    {
      $string .= " arr[" . $i . "],";
    }
    chop( $string); #removes the last ',' 
    $string .= ");\n";
  }
  elsif ($size == 1)
  {
  #CHANGE HERE! (+2 to +1)
    $string .= "(" . $type . ")mxGetScalar(ssGetSFcnParam(S, " . $$index . "+1)));\n";
  }
  
  return $string;
}

##########################################################################
# setupCharParameterStartString
# setup all inputs that must be of type char*
##########################################################################
sub setupCharParameterStartString{
  
  my ($name, $size, $type, $index) = @_;
  my $string = "";
  
  if ($size != 1)
  {
    $string = $string .
    "        char stackspace[128];\n" .
    "        char *stringbuf = stackspace;\n" .
    "        int buflen = mxGetN((ssGetSFcnParam(S, " . $$index ."+1)))+1;\n" .
    "        if (buflen > 128) {\n" .
    "          // use malloc for oversize strings\n" .
    "          stringbuf = reinterpret_cast<char *>(mxMalloc(buflen));\n" .
    "        }\n" .
    "        mxGetString((ssGetSFcnParam(S, " . $$index . "+1)), stringbuf, buflen);\n" .
    "        filter->Set" . $name . "(stringbuf); // wanted as parameter\n" .
    "        if (buflen > 128) {\n" .
    "          mxFree(stringbuf);\n" .
    "        }\n";
  }
  else 
  {
    $string = $string .
    "        char string = static_cast<char>((mxGetChars(ssGetSFcnParam(S," . $$index . "+1)))[0]);\n" .
    "        filter->Set". $name . "(string); //wanted as parameter\n" ;
  }
  return $string;
}

###########################################################
# setupProcessOutputString
# process the inputs of all input ports
###########################################################
sub setupProcessOutputString{
  my ($filterHash, $index) = @_;
  my $outputString = "";
  
  my $filterName = $filterHash->{"Filter_Name"};
  
  foreach my $output (@{$filterHash->{"Outputs"}})
  {
    my $outputType = $output->{"Output_Type"};
    my $outputName = $output->{"Output_Name"};
    $outputString = $outputString .
    "      if (static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $$index . "))) == 1)\n";
    $outputString = $outputString . "      {\n" .
    "        " . $outputType . " **OutputPort;\n" .
    "        OutputPort = reinterpret_cast<" . $outputType . "**>(ssGetOutputPortSignal(S, outputPortIndex));\n" .
    "        OutputPort[0] = filter";
    if ($outputName eq "Self")
    {
      $outputString .= ";\n";
    }
    else 
    {
      $outputString = $outputString . "->Get" . $outputName . "();\n";
    }
    $outputString = $outputString .
    "        outputPortIndex++;\n" .
    "      }\n" ;
    $$index++;		
  }
  return $outputString;
}

#########################################################################
# setupProcessParameterOutputString
# the string to be used in mdlOutput that will allow any parameters that are being used as inputs to change throughout the simulation
#########################################################################
sub setupProcessParameterOutputString{
  my $filterHash = shift;
  my $string = "";
  my $index = 0;
  $index = scalar @{$filterHash->{"Inputs"}} if $filterHash->{"Inputs"};

  foreach my $param (@{$filterHash->{"Filter_Parameters"}})
  {
    my $paramName = $param->{"Parameter_Name"};
    my $paramSize = $param->{"Parameter_Size"};
    my $paramType = $param->{"Parameter_Type"};

    if ($paramType ne "char")
    {
      $string = $string . setupProcessParameterOutputNumericString($paramName, $paramType, $paramSize, $index);
    }
    else 
    {
      $string = $string . setupProcessParameterOutputCharString($paramName, $paramType, $paramSize, $index);
    }
    $index = $index + 2;
  }
  return $string;
}

##########################################################################
# setupProcessParameterOutputNumericString
# setup the string that will handle the case that a numeric parameter is promoted to be an input or output in mdlOutputs
##########################################################################
sub setupProcessParameterOutputNumericString{
  my ($paramName, $paramType, $paramSize, $index) = @_;
  my $string = "";
  
  $string = $string .
  "    if (static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $index . "))) == 2) // wanted as input\n" .
  "    {\n";
  if ($paramSize != 1)
  {
    $string = $string .
    "      " . $paramType . " *arr = (reinterpret_cast<" . $paramType . "*>(const_cast<void*>(ssGetInputPortSignal(S, inputPortIndex))));\n";
  }
  $string .=  "      filter->Set" . $paramName . "(";
  if ($paramSize != 1)
  {
    for (my $i = 0; $i < $paramSize; $i++)
    {
      $string .= " arr[" . $i . "],";
    }
    chop($string); #removes the last ',' 
    $string .= ");\n";
  }
  elsif ($paramSize == 1)
  {
    $string .= "(reinterpret_cast<" . $paramType . "*>(const_cast<void*>(ssGetInputPortSignal(S, inputPortIndex))))[0]);\n";
  }
  $string = $string . "      inputPortIndex++;\n" .
    "    }\n" ;
    #CHANGE HERE! (+ 1 to nothing and == 1 to == 4)
  $string = $string . "    if (static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $index ."))) == 4) // wanted as output\n" .
    "    {\n" .
    "      " . $paramType . " ";
  if ($paramSize != 1)
  {
    $string .= "*"; 
  }
  $string = $string . "parameter;\n" .
    "      parameter = filter->Get" . $paramName . "();\n" .
    "      " . $paramType . " *outputValue = reinterpret_cast<" . $paramType . "*>(ssGetOutputPortSignal(S, outputPortIndex));\n" ;
  if ($paramSize == 1)
  {
    $string = $string . "      outputValue[0] = parameter;\n";
  }
  else 
  {
    $string = $string . "      for (j = 0; j < " . $paramSize . "; j++){\n" .
    "        outputValue[j] = parameter[j];\n" .
    "      }\n";
  }
  $string = $string . "      outputPortIndex++;\n" .
  "    }\n" ;
    
  return $string;
}	

##########################################################################
# setupProcessParameterOutputCharString
# setup the string that will handle the case that a char parameter is promoted to be an input
# Newly added... not tested... should fix so not so much repetitiveness going on
##########################################################################
sub setupProcessParameterOutputCharString{
  my ($paramName, $paramType, $paramSize, $index) = @_;
  my $string = "";
  
  if ($paramSize != 1)
  {
    $string = $string. "    if (static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $index . "))) == 2) \n" .
      "    {\n" . 
      "      char **pointer = reinterpret_cast<char**>(const_cast<void*>(ssGetInputPortSignal(S, inputPortIndex)));\n" .
      "      if (strcmp(pointer[0], \"\") != 0)\n" .
      "      {\n" .
      "        filter->Set" . $paramName . "(pointer[0]);\n" .
      "        inputPortIndex++;\n" .
      "      }\n" .
      "    }\n" ;
      #CHANGE HERE! (+1 to nothing and ==1 to ==4)
    $string = $string . "    if (static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $index . "))) == 4) \n" .
      "    {\n" .
      "      char *parameter;\n" .
      "      parameter = (char*)( filter->Get" . $paramName . "() );\n" .
      "      char **outputValue = reinterpret_cast<char **>(ssGetOutputPortSignal(S, outputPortIndex));\n" .
      "      outputValue[0] = parameter;\n" .
      "      outputPortIndex++;\n" .
      "    }\n" ;
  }
  else
  {
    $string = $string. "    if (static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $index . "))) == 2) \n" .
      "    {\n" . 
      "      char *pointer = reinterpret_cast<char*>(const_cast<void*>(ssGetInputPortSignal(S, inputPortIndex)));\n" .
      "      filter->Set" . $paramName . "(pointer[0]);\n" .
      "        inputPortIndex++;\n" .
      "    }\n" ;
      # CHANGE HERE! (+1 to nothing and ==1 to ==4)
    $string = $string . "    if (static_cast<int>(mxGetScalar(ssGetSFcnParam(S," . $index . "))) == 4)\n" .
      "    {\n" .
      "      char parameter;\n" .
      "      parameter = filter->Get" . $paramName . "();\n" .
      "      char *outputValue = reinterpret_cast<char*>(ssGetOutputPortSignal(S, outputPortIndex));\n" .
      "      outputValue[0] = parameter;\n" .
      "      outputPortIndex++;\n" .
      "    }\n";
  }
  return $string;
}
  
#########################################################################
# setupInitialize
# the string to be used in mdlOutput that will allow render windows to be initialized (for either windows or linux)
#########################################################################
sub setupInitialize{
  my $filterName = shift;
  my $string = "";
  
  $string = $string .
      "  filter->Initialize();\n" .
      "  filter->Render();\n";
  if ($^O eq "linux"){
    $string = $string .
      "  XtAppContext app = vtkXRenderWindowInteractor::SafeDownCast(filter)->GetApp();\n" .
      "  if (XtAppPending(app))\n" .
      "  {\n" .
      "    XEvent event;\n" .
      "    XtAppNextEvent(app, &event);\n" .
      "    XtDispatchEvent(&event);\n" .
      "  }\n" ;
  }
  return $string;
}

	
	
