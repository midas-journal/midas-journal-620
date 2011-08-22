package TPPGen;

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
#
# TPPGen.pm
###############################################

use strict;
use Switch;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(TPPGen);

sub TPPGen {

  my ($filterHash, $dimensionality, $directory, $templateFile) = @_;

  # Read the input file into a single string
  # The ImageToImageRegistrationHelper class requires a separate template file because it cannot be passed an output pointer from MATLAB and
  # instead must copy its output from the output ITK Image to a MATLAB array after the Update() has occured.
  if (substr($filterHash->{"Name"}, 0, length($filterHash->{"Name"}) - 3) eq "ImageToImageRegistrationHelper") {
    open (INFILE, "<FilterBlockRegHelper.tpp.in");
  }
  else {
    open (INFILE, "<" . $templateFile);
  }
  undef $/;
  my $content = <INFILE>;
  
  $/ = "\n";
  close INFILE;
  
  # Create the output file
  # Transforms are not specific to pixeltype
  if ($templateFile eq "TransformFilterBlock.tpp.in") {
    open (OUTFILE, ">$directory/SimITK" . 
      substr($filterHash->{"Name"},0,length($filterHash->{"Name"}) - 3) . $dimensionality . "D.tpp");
  }
  else {
    open (OUTFILE, ">$directory/SimITK" . $filterHash->{"Name"} . ".tpp");
  }
  
  # FILTER_NAME
  my $filterName = $filterHash->{"Name"};
  $content =~ s/\@FILTER_NAME\@/$filterName/g;
  #ITK_FILTER_NAME (the filterName minus its 3-character suffix)
  my $ITKFilterName = substr($filterName, 0, length($filterName) - 3);
  $content =~ s/\@ITK_FILTER_NAME\@/$ITKFilterName/g;
  # DIMENSIONALITY_CODE
  my $dimensionalityCode = $dimensionality . "D";
  $content =~ s/\@DIMENSIONALITY_CODE\@/$dimensionalityCode/g;
  # NUM_INPUTS
  my $numInputs = (defined $filterHash->{"Inputs"}) ? scalar @{$filterHash->{"Inputs"}} : 0;
  $content =~ s/\@NUM_INPUTS\@/$numInputs/g;
  # NUM_OUTPUTS
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  $content =~ s/\@NUM_OUTPUTS\@/$numOutputs/g;
  #NUM_SPECIAL_INPUTS
  my $numSpecialInputs = (defined $filterHash->{"Special_Inputs"}) ? scalar @{$filterHash->{"Special_Inputs"}} : 0;
  $content =~ s/\@NUM_SPECIAL_INPUTS\@/$numSpecialInputs/g;
  
  # MUTATOR_METHODS
  my $mutatorsString = mutatorsString($filterHash);
  $content =~ s/\@MUTATOR_METHODS\@/$mutatorsString/g;
  # ACCESSOR_METHODS
  my $accessorsString = accessorsString($filterHash);
  $content =~ s/\@ACCESSOR_METHODS\@/$accessorsString/g;
  
  #MEMBER_VARIABLES
  my $memberVariablesString = memberVariablesString($filterHash);
  $content =~ s/\@MEMBER_VARIABLES\@/$memberVariablesString/g;  
  # ITK_FILTER_TYPEDEF
  my $ITKFilterTypedefString = ITKFilterTypedefString($filterHash);
  $content =~ s/\@ITK_FILTER_TYPEDEF\@/$ITKFilterTypedefString/g;
  # SPECIAL_INPUT_TYPEDEFS
  my $specialInputTypedefString = specialInputTypedefString($filterHash);
  $content =~ s/\@SPECIAL_INPUT_TYPEDEFS\@/$specialInputTypedefString/g;
  
  # CREATE_INPUT_IMAGES
  my $createInputImagesString = createInputImagesString($filterHash);
  $content =~ s/\@CREATE_INPUT_IMAGES\@/$createInputImagesString/g;
  
  # SET_FILTER_PARAMETERS: Convert ITK parameter types to Matlab if necessary. Then set.
  my $setFilterParametersString = setFilterParametersString($filterHash);
  $content =~ s/\@SET_FILTER_PARAMETERS\@/$setFilterParametersString/g;
  # SET_SPECIAL_INPUTS
  my $setSpecialInputsString = setSpecialInputsString($filterHash);
  $content =~ s/\@SET_SPECIAL_INPUTS\@/$setSpecialInputsString/g;
  
  # GET_INPUT_MATRICES
  my $getInputMatricesString = getInputMatricesString($filterHash);
  $content =~ s/\@GET_INPUT_MATRICES\@/$getInputMatricesString/g;
  # GET_OUTPUT_MATRICES
  my $getOutputMatricesString = getOutputMatricesString($filterHash);
  $content =~ s/\@GET_OUTPUT_MATRICES\@/$getOutputMatricesString/g;
  
  # SET_INPUT_DATA_INFORMATION
  my $setInputDataInformationString = setInputDataInformationString($filterHash);
  $content =~ s/\@SET_INPUT_DATA_INFORMATION\@/$setInputDataInformationString/g;
  # CONVERT_MATRICES_TO_IMAGES
  my $convertMatricesToImagesString = convertMatricesToImagesString($filterHash);
  $content =~ s/\@CONVERT_MATRICES_TO_IMAGES\@/$convertMatricesToImagesString/g;

  # GET_OUTPUT_SIZE
  my $getOutputSizeString = getOutputSizeString($filterHash);
  $content =~ s/\@GET_OUTPUT_SIZE\@/$getOutputSizeString/g;  
  # CONVERT_IMAGES_TO_MATRICES
  my $convertImagesToMatricesString = convertImagesToMatricesString($filterHash);
  $content =~ s/\@CONVERT_IMAGES_TO_MATRICES\@/$convertImagesToMatricesString/g;
  # SET_INPUT_IMAGES
  my $setInputImagesString = setInputImagesString($filterHash);
  $content =~ s/\@SET_INPUT_IMAGES\@/$setInputImagesString/g;
  # SET_OUTPUT_DATA_INFORMATION
  my $setOutputDataInformationString = setOutputDataInformationString($filterHash);
  $content =~ s/\@SET_OUTPUT_DATA_INFORMATION\@/$setOutputDataInformationString/g;
  
  print OUTFILE $content;
  close OUTFILE;
}


##########################################################
# mutatorsString
# Generates a string for the mutator methods
# ex: void SetLower(double* value) { m_Lower = value; }
##########################################################
sub mutatorsString {
  my $filterHash = shift;
  my $string = ""; 
  foreach my $param ( @{$filterHash->{"Parameters"}} ) {
    
    my $paramName = $param->{"Parameter_Name"};
    $string = $string . "\tvoid Set" . $paramName . "(";
  
    # The datatype will either be an explicit C++ primitive or the pixel type of the input/output image
    # A double is always used if the datatype is an ITK or Enum parameter type. This will be turned into
    # a pointer to a double if the parameter is found to be not scalar (likely the case).
    if ($param->{"ITK_Parameter_Type"} ne "" || 
      $param->{"Enum_Parameter_Type"} ne "") {
      $string = $string . "double";
    }
    else {
      my $paramType = $param->{"Parameter_Type"};
      if (isInputPixelType($paramType, $filterHash)) {
        $string = $string . "typename InputPortType::PixelType";
      }
      elsif (isOutputPixelType($paramType, $filterHash)) {
        $string = $string . "typename OutputPortType::PixelType";
      }
      else {
        $string = $string . $paramType;
      }
    }
    
    # Convert the datatype to a datatype pointer if the parameter is not scalar
    my $paramSize = $param->{"Parameter_Size"};
    if ($paramSize ne "1,1") {
      $string = $string . "*";
    }
    $string = $string . " value) {\n\t\tm_" . $paramName . " = value;\n\t}\n";
  }
  return $string;
}

##########################################################
# accessorsString
# Generates a string for the accessor methods
# ex: double* GetLower() { return m_Lower; }
##########################################################
sub accessorsString {
  my $filterHash = shift;
  my $string = ""; 
  foreach my $param ( @{$filterHash->{"Parameters"}} ) {
  
    $string = $string . "\t"; #indent
    # The datatype will either be an explicit C++ primitive or the pixel type of the input/output image
    # A double is always used if the datatype is an ITK or Enum parameter type. This will be turned into
    # a pointer to a double if the parameter is found to be not scalar (likely the case).
    if ($param->{"ITK_Parameter_Type"} ne "" ||
      $param->{"Enum_Parameter_Type"} ne "") {
      $string = $string . "double";
    }
    else {
      my $paramType = $param->{"Parameter_Type"};
      if (isInputPixelType($paramType, $filterHash)) {
        $string = $string . "typename InputPortType::PixelType";
      }
      elsif (isOutputPixelType($paramType, $filterHash)) {
        $string = $string . "typename OutputPortType::PixelType";
      }
      else {
        $string = $string . $paramType;
      }
    }
    
    # Convert the datatype to a datatype pointer if the parameter is not scalar
    my $paramSize = $param->{"Parameter_Size"};
    if ($paramSize ne "1,1") {
      $string = $string . "*";
    }
  
    my $paramName = $param->{"Parameter_Name"};
    $string = $string . " Get" . $paramName . "() {\n\t\t return m_" .
        $paramName . ";\n\t}\n";
  }
  return $string;
}

##########################################################
# memberVariablesString
# Generates a string for the member variable declarations
# ex: double* m_Lower;
##########################################################
sub memberVariablesString {
  my $filterHash = shift;
  my $string = "";
  foreach my $param ( @{$filterHash->{"Parameters"}} ) {
    
    $string = $string . "\t"; #indent
    # The datatype will either be an explicit C++ primitive or the pixel type of the input/output image
    # A double is always used if the datatype is an ITK or Enum parameter type. This will be turned into
    # a pointer to a double if the parameter is found to be not scalar (likely the case).
    if ($param->{"ITK_Parameter_Type"} ne "" ||
      $param->{"Enum_Parameter_Type"} ne "") {
      $string = $string . "double";
    }
    else {
      my $paramType = $param->{"Parameter_Type"};
      if (isInputPixelType($paramType, $filterHash)) {
        $string = $string . "typename InputPortType::PixelType";
      }
      elsif (isOutputPixelType($paramType, $filterHash)) {
        $string = $string . "typename OutputPortType::PixelType";
      }
      else {
        $string = $string . $paramType;
      }
    }
    
    # Convert the datatype to a datatype pointer if the parameter is not scalar
    my $paramSize = $param->{"Parameter_Size"};
    if ($paramSize ne "1,1") {
      $string = $string . "*";
    }
    
    # Complete the variable declaration
    $string = $string . " m_" . $param->{"Parameter_Name"} . ";\n";
  }
  return $string;
}

##########################################################
# ITKFilterTypedefString
# Generates a typedef for the ITK filter
# ex: typedef itk::@ITK_FILTER_NAME@<InputImageType, OutputImageType> ITKFilterType;
##########################################################
sub ITKFilterTypedefString {
  my $filterHash = shift;
  my $string = "";
  my $ITKFilterName = substr($filterHash->{"Name"}, 0, 
    length($filterHash->{"Name"}) - 3);
  
  $string = $string . "\t\ttypedef itk::" . $ITKFilterName . "<";
  
  # Template parameters
  my $firstParam = 1;
  foreach my $templateParameter ( @{$filterHash->{"Template_Parameters"}} ) {
    if ($firstParam) { $firstParam = 0; }
    else { $string = $string . ","; }
    switch ($templateParameter) {
      case "TImage" { $string = $string . "InputImageType"; }
      case "TInputImage" { $string = $string . "InputImageType"; }
      case "TOutputImage" { $string = $string . "OutputImageType"; }
      case "TScalarType" { $string = $string . "double"; }
      case "TCoordRep" { $string = $string . "double"; }
      case "NDimensions" { $string = $string . "InputPortType::ImageDimension"; }
      case "NInputDimensions" { $string = $string . "InputPortType::ImageDimension"; }
      case "NOutputDimensions" { $string = $string . "OutputPortType::ImageDimension"; }
      else    { }
    }
  }
  $string = $string . "> ITKFilterType;\n";
  
  return $string;
}

##########################################################
# specialInputTypedefString
# Generates a typedef for special inputs
# ex: typedef ITKFilterType::NodeContainer NodeContainer;
##########################################################
sub specialInputTypedefString {
  my $filterHash = shift;
  my $string = "";
  my @specialTypes = ("NodeContainer","InterpolatorType","TransformType");
  
  # Create one typedef for each special input type that appears at least once in the filter
  foreach my $type (@specialTypes) {
    foreach my $input ( @{$filterHash->{"Special_Inputs"}} ) {
      if ($type eq $input->{"ITK_Parameter_Type"}) {
        $string = $string . "\t\ttypedef typename ITKFilterType::" . $type . " " .
          $type . ";\n";
        last;
      }
    }
  }
  return $string;
}

##########################################################
# isInputPixelType
# Returns true if 'datatype' is equal to any of the input image types stored in 'filterHash'
##########################################################
sub isInputPixelType {
  my ($datatype, $filterHash) = @_;
  
  foreach my $input ( @{$filterHash->{"Inputs"}} ) {
    if ($datatype eq $input->{"Input_Type"}) {
      return 1;
    }
  }
  return 0;
}

##########################################################
# isOutputPixelType
# Returns true if 'datatype' is equal to any of the output image types stored in 'filterHash'
##########################################################
sub isOutputPixelType {
  my ($datatype, $filterHash) = @_;
  
  foreach my $output ( @{$filterHash->{"Outputs"}} ) {
    if ($datatype eq $output->{"Output_Type"}) {
      return 1;
    }
  }
  return 0;
}

##########################################################
# createInputImagesString
# Generates a string for the input image instantiations
# ex: InputImageType::Pointer Input = InputImageType::New();
##########################################################
sub createInputImagesString {
  my $filterHash = shift;
  my $string = "";
  
  foreach my $input ( @{$filterHash->{"Inputs"}} ) {
    my $inputName = $input->{"Input_Name"};
    $string = $string .
      "\t\ttypename InputImageType::Pointer " . $inputName . " = InputImageType::New();\n";
  }
  return $string;
}

##########################################################
# setFilterParametersString
# Generates a string to set the filter parameters.  If necessary, parameters are converted from Matlab
# to ITK types before they are set.
# ex:
# ITKFilterType::ArrayType Lower;
# for (int dimension = 0; dimension < InputPortType::ImageDimension; dimension++) {
#    Lower[dimension] = m_Lower[dimension];
# }
# filter->SetLower(Lower);
##########################################################
sub setFilterParametersString {
  my $filterHash = shift;
  my $string = "";

  foreach my $param ( @{$filterHash->{"Parameters"}} ) {
    my $paramName = $param->{"Parameter_Name"};
    $string = $string . "\t\tfilter->Set" . $paramName . "(";
        
    # Convert parameter types from Matlab to ITK if necessary (i.e. an ITK_Parameter_Type tag is found)
    # Convert parameter types from Matlab to Enum type if necessary (i.e. an Enum_Parameter_Type tag is found)
    my $ITKType = $param->{"ITK_Parameter_Type"};
    my $enumType = $param->{"Enum_Parameter_Type"};
    if ($ITKType ne "") {

      my $convertITKTypeString = "";
      #    Conversion for scalar variables
      my $paramSize = $param->{"Parameter_Size"};
      if ($paramSize eq "1,1") {
        $convertITKTypeString = $convertITKTypeString .
          "\t\ttypename ITKFilterType::" . $ITKType . " " . $paramName . " = m_" . $paramName . ";\n";
      }
      # Conversion for non-scalar variables
      else {
        $convertITKTypeString = $convertITKTypeString . 
          "\t\ttypename ITKFilterType::" . $ITKType . " " .$paramName . ";\n" .
          "\t\tfor (int dimension = 0; dimension < InputPortType::ImageDimension; dimension++) {\n" .
          "\t\t\t" . $paramName . "[dimension] = m_" . $paramName . "[dimension];\n" .
          "\t\t}\n";
      }
      # Prepend the datatype conversion string to the set parameters string
      $string = $convertITKTypeString . $string;
    }
    elsif ($enumType ne "") {
      my $convertEnumTypeString =
        "\t\tint " . $paramName . "Int = static_cast<int>(m_" . $paramName . ");\n" .
        "\t\ttypename ITKFilterType::" . $enumType . " " . $paramName ."\n" .
          "\t\t\t= static_cast<typename ITKFilterType::" . $enumType . ">( " . $paramName . "Int);\n";
      # Prepend the datatype conversion string to the set parameters string
      $string = $convertEnumTypeString . $string;
    }
    # No conversion necessary (i.e. the original class member variable is used) if the datatype is not specifically an ITK or Enum type
    else {
      $string = $string . "m_";
    }
    $string = $string . $paramName . ");\n";
  }
  return $string;
}

##########################################################
# setSpecialInputsString
# Generates a string for setting the special inputs
# ex:
# void* SpecialInput0 = this->GetSpecialInput(0).GetPointer();
# NodeContainer::Pointer TrialPoints = reinterpret_cast<NodeContainer*>(SpecialInput0);
# filter->SetTrialPoints(TrialPoints);
##########################################################
sub setSpecialInputsString {
  my $filterHash = shift;
  my $numSpecialInputs = scalar @{$filterHash->{"Special_Inputs"}};
  my $string = "";
  
  for (my $i = 0; $i < $numSpecialInputs; $i++) {
    my $inputName = $filterHash->{"Special_Inputs"}->[$i]->{"Special_Input_Name"};
    my $ITKType = $filterHash->{"Special_Inputs"}->[$i]->{"ITK_Parameter_Type"};
    $string = $string . 
      "\t\tvoid* SpecialInput" . $i . " = this->GetSpecialInput(" . $i . ").GetPointer();\n" .
      "\t\ttypename " . $ITKType . "::Pointer " . $inputName . " = reinterpret_cast<" . $ITKType .
        "*>(SpecialInput" . $i . ");\n" .
      "\t\tfilter->Set" . $inputName . "(" . $inputName . ");\n\n";
  }
  return $string;
}

##########################################################
# getInputMatricesString
# Generates a string to get the input matrices
# ex: InputPortType::PixelType *inputMatrix0 = this->GetInput(0).GetArray();
##########################################################
sub getInputMatricesString {
  my $filterHash = shift;
  my $numInputs = scalar @{$filterHash->{"Inputs"}};
  my $string = "";
  
  for (my $i = 0; $i < $numInputs; $i++) {
    $string = $string .
      "\t\ttypename InputPortType::PixelType *inputMatrix" .$i. " = this->GetInput(" .$i. ").GetArray();\n";
  }
  return $string;
}

##########################################################
# getOutputMatricesString
# Generates a string to get the output matrices
# ex: OutputPortType::PixelType *outputMatrix0 = this->GetOutput(0).GetArray();
##########################################################
sub getOutputMatricesString {
  my $filterHash = shift;
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $string = "";
  
  for (my $i = 0; $i < $numOutputs; $i++) {
    $string = $string .
      "\t\ttypename OutputPortType::PixelType *outputMatrix" .$i. " = this->GetOutput(" .$i. ").GetArray();";
  }
  return $string;
}

##########################################################
# setInputDataInformationString
# Generates a string to set the size, spacing and origin of the input data
# ex: 
# unsigned int* inputSize0 = this->GetInput(0).GetSize();
# Input->SetSpacing(this->GetInput(0).GetSpacing());
# Input->SetOrigin(this->GetInput(0).GetOrigin());
##########################################################
sub setInputDataInformationString {
  my $filterHash = shift;
  my $numInputs = scalar @{$filterHash->{"Inputs"}};
  my $string = "";
  
  for (my $i = 0; $i < $numInputs; $i++) {
    my $inputName = $filterHash->{"Inputs"}->[$i]->{"Input_Name"};
    # Set Size
    $string = $string .
       "\t\tunsigned int* inputSize" . $i . " = this->GetInput(" . $i . ").GetSize();\n";
    # Set Spacing
    $string = $string . 
       "\t\t" . $inputName . "->SetSpacing(this->GetInput(" . $i . ").GetSpacing());\n";
    # Set Origin
    $string = $string .
       "\t\t" . $inputName . "->SetOrigin(this->GetInput(" . $i . ").GetOrigin());\n";
  }
  return $string;
}

##########################################################
# convertMatricesToImagesString
# Generates a string to translate the input matrix into an image
# ex: ConvertMatrixToImage(Input.GetPointer(), inputMatrix0, inputSize0);
##########################################################
sub convertMatricesToImagesString {
  my $filterHash = shift;
  my $numInputs = scalar @{$filterHash->{"Inputs"}};
  my $string = "";
  
  for (my $i = 0; $i < $numInputs; $i++) {
    my $inputName = $filterHash->{"Inputs"}->[$i]->{"Input_Name"};
    $string = $string .
      "\t\tConvertMatrixToImage(inputMatrix" . $i . ", " . $inputName.
      ".GetPointer(), inputSize" . $i . ");\n";
  }
  return $string;
}

##########################################################
# getOutputSizeString
# Generates a string to get the size of the output
# ex: unsigned int* outputSize0 = this->GetOutput(0).GetSize();
##########################################################
sub getOutputSizeString{
  my $filterHash = shift;
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $string = "";
  
  for (my $i = 0; $i < $numOutputs; $i++) {
    my $outputName = $filterHash->{"Outputs"}->[$i]->{"Output_Name"};
    # Set Size
    $string = $string .
       "\t\tunsigned int* outputSize" . $i . " = this->GetOutput(" . $i . ").GetSize();\n";
  }
  return $string;
}

##########################################################
# convertImagesToMatricesString
# Generates a string to translate the filter's output into an array
# ex: ConvertImageToMatrix(outputMatrix0, filter->GetOutput());
##########################################################
sub convertImagesToMatricesString {
  my $filterHash = shift;
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $string = "";
  my $ITKFilterName = substr($filterHash->{"Name"}, 0, 
    length($filterHash->{"Name"}) - 3);
  
  # If ImageToImageRegistrationHelper is used, the conversion method with 2 parameters instead of 3 must be used.
  for (my $i = 0; $i < $numOutputs; $i++) {
    if ($ITKFilterName eq "ImageToImageRegistrationHelper") {
        $string = $string .
          "\t\tConvertImageToMatrix(filter->Get" . 
          $filterHash->{"Outputs"}->[$i]->{"Output_Name"} . "(), outputMatrix" . $i . ");\n";
    }
    else {
        $string = $string .
          "\t\tConvertImageToMatrix(filter->Get" . 
          $filterHash->{"Outputs"}->[$i]->{"Output_Name"} . "(), outputMatrix" . $i
          . ", outputSize" . $i . ");\n";
    }
  }
  return $string;
}

##########################################################
# setInputImagesString
# Generates a string to set the input images
# ex: filter->SetInput(Input);
##########################################################
sub setInputImagesString {
  my $filterHash = shift;
  my $string = "";
  
  foreach my $input ( @{$filterHash->{"Inputs"}} ) {
    $string = $string .
      "\t\tfilter->Set" . $input->{"Input_Name"} . "(" . $input->{"Input_Name"} . ");\n";
  }
  return $string;
}

##########################################################
# setOutputDataInformationString
# Generates a string to set the origin and spacing information of the output images
# ex: 
# typename OutputImageType::PointType OutputOriginITK = filter->GetOutput()->GetOrigin();
# typename OutputImageType::SpacingType OutputSpacingITK = filter->GetOutput()->GetSpacing();
# double OutputOriginSim[OutputPortType::ImageDimension];
# double OutputSpacingSim[OutputPortType::ImageDimension];
#
# for (int i = 0; i<OutputPortType::ImageDimension; i++){
#     OutputOriginSim[i] = OutputOriginITK[i];
#     if (OutputSpacingITK[i] == 0) { OutputSpacingSim[i] = 1.0; }
#     else{  OutputSpacingSim[i] = OutputSpacingITK[i]; }
# }
#
# this->GetOutput(0).SetOrigin(OutputOriginSim);
# this->GetOutput(0).SetSpacing(OutputSpacingSim);
##########################################################
sub setOutputDataInformationString {
  my $filterHash = shift;
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $string = "";
  
  for (my $i = 0; $i < $numOutputs; $i++) {
    my $outputName = $filterHash->{"Outputs"}->[$i]->{"Output_Name"};
    $string = $string .
      "\t\ttypename OutputImageType::PointType " .$outputName. "OriginITK = " . 
        "filter->Get" .$outputName. "()->GetOrigin();\n" .
      "\t\ttypename OutputImageType::SpacingType " .$outputName. "SpacingITK = " .
        "filter->Get" .$outputName. "()->GetSpacing();\n" .
      "\n" .
      "\t\tdouble " . $outputName . "OriginSim[OutputPortType::ImageDimension];\n" .
      "\t\tdouble " . $outputName . "SpacingSim[OutputPortType::ImageDimension];\n" .
      "\n" .
      "\t\tfor (int i = 0; i<OutputPortType::ImageDimension; i++){\n" .
        "\t\t\t" . $outputName . "OriginSim[i] = " . $outputName . "OriginITK[i];\n" .
        "\t\t\tif (" . $outputName . "SpacingITK[i] == 0){\n" .
          "\t\t\t\t" . $outputName . "SpacingSim[i] = 1.0;\n" .
        "\t\t\t}\n" .
        "\t\t\telse{\n" .
          "\t\t\t\t" . $outputName . "SpacingSim[i] = " . $outputName . "SpacingITK[i];\n" .
        "\t\t\t}\n" .
      "\t\t}\n" .            
      "\n" .
      "\t\tthis->GetOutput(" . $i . ").SetOrigin(" . $outputName . "OriginSim);\n" .
      "\t\tthis->GetOutput(" . $i . ").SetSpacing(" . $outputName . "SpacingSim);\n";
  }
  return $string;
}

1;
