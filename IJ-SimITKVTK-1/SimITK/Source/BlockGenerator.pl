#!/usr/bin/perl

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
# BlockGenerator.pl
#
# Automatically lists the filter names inside the XML or generates the code for a 
# Virtual Block, given an XML description 
#
# USAGE: 
# BlockGenerator.pl <flag> <XML_file> <dimensionality> <input_pixeltype> <output_pixeltype> <directory>
# where <flag> is 
# -LIST: results in a list of all filter names in the XML file. 
# -GENERATE: generate the code for the virtual blocks with the specified 
# dimensionality and pixel types
# <directory> is the directory where the generated code should be placed
#
###############################################

use strict;
use Switch;
use XML::DOM;
use TPPGen;
use SFunctionGen;
use LibraryGen;
use FilterMaskGen;
use BaseClassCopy;

# Check that 6 arguments are given
my $numArgs = $#ARGV + 1;
die "\nUSAGE:" . 
    "BlockGenerator.pl <flag> <XML_file> <dimensionality> " .
    "<input_pixeltype> <output_pixeltype> <directory>\n" 
    unless $numArgs == 6;

#The first argument is the flag that determines whether simply a list of filter names
# is required or the full source code
my $flag = shift;
die "\nUSAGE:\n" .
    "<flag> = -LIST to list filter names\n" .
    "or -GENERATE to generate source code\n"
    unless $flag eq "-LIST" || $flag eq "-GENERATE";
#if ($flag  eq "-LIST"){
#    print "\"";
#}

# The second argument is the name of the input XML file
my $xmlFile = shift;
die "ERROR: Input file not found"
  unless -f $xmlFile;
  
# The third, fourth and fifth arguments should be dimensionality, inputPixeltype and outputPixeltype respectively
my $dimensionality = shift;
my $inputPixeltype = shift;
my $outputPixeltype = shift;

#The sixth argument is the bin directory where the generated source code should be placed
my $directory = shift;

# Read the input file and create an XML DOM data structure
my $parser = new XML::DOM::Parser;
my $doc = $parser->parsefile ($xmlFile);

# A nodelist where each node represents a transform description
my $transformsNodeList = $doc->getElementsByTagName("Transform");
my $numTransforms = $transformsNodeList->getLength;

# A nodelist where each node represents an interpolator description
my $interpolatorsNodeList = $doc->getElementsByTagName("Interpolator");
my $numInterpolators = $interpolatorsNodeList->getLength;

# A nodelist where each node represents a filter description
my $filtersNodeList = $doc->getElementsByTagName("Filter");
my $numFilters = $filtersNodeList->getLength;

my $filterNameList = ""; #Stores the names of all filters, delimited by semicolon, 
                        #This is then converted into a list in cmake. 

# Variables to store the code for generating mask for each block.                         
my $maskContent = ""; 
# A separate library is created for transforms because they are not specific to pixeltype
my $transformMaskContent = "";

#Create hashes to represent the position information of the filter's mask in Simulink 
my %positionLeftCol = ();
$positionLeftCol{"left"} = 90;
$positionLeftCol{"top"} = 190;
$positionLeftCol{"right"} = 190;
$positionLeftCol{"bottom"} = 150;

my %positionRightCol = ();
$positionRightCol{"left"} = 350;
$positionRightCol{"top"} = 190;
$positionRightCol{"right"} = 450;
$positionRightCol{"bottom"} = 150;

my %transformPositionLeftCol = ();
$transformPositionLeftCol{"left"} = 90;
$transformPositionLeftCol{"top"} = 20;
$transformPositionLeftCol{"right"} = 190;
$transformPositionLeftCol{"bottom"} = 50;

my %transformPositionRightCol = ();
$transformPositionRightCol{"left"} = 350;
$transformPositionRightCol{"top"} = 20;
$transformPositionRightCol{"right"} = 450;
$transformPositionRightCol{"bottom"} = 50;

#There are two columns that display the filter masks.  If we're on the left column, then 
# $onLeftColumn is true, = 1
my $onLeftColumn = 1;
my $transformOnLeftColumn = 1;

# Loop over each transform and filter in turn
my $numObjects = $numTransforms + $numInterpolators + $numFilters;
for (my $filterInd=0; $filterInd < $numObjects; $filterInd++) {  
  
    #Create a hash to represent the filter information
    my %filterHash = ();
  
    my $filterNode;
    if ($filterInd < $numTransforms) {
      $filterNode = $transformsNodeList->item ($filterInd);
      (\%filterHash)->{"Object_Type"} = "Transform";
      #Transforms will always have zero inputs and one special output, 'self'
      (\%filterHash)->{"Special_Outputs"}->[0]->{"Special_Output_Name"} = "self";
    }
    elsif ($filterInd < $numTransforms + $numInterpolators) {
      $filterNode = $interpolatorsNodeList->item ($filterInd - $numTransforms);
      (\%filterHash)->{"Object_Type"} = "Interpolator";
      #Interpolators will always have zero inputs and one special output, 'self'
      (\%filterHash)->{"Special_Outputs"}->[0]->{"Special_Output_Name"} = "self";
    }
    else {
      $filterNode = $filtersNodeList->item ($filterInd - $numTransforms - $numInterpolators);
      (\%filterHash)->{"Object_Type"} = "Filter";
    }
    
    #finds out if allowed datatypes and dimensionalities are specified in the xml 
    my $datatypesAreSpecified = findAllowedDatatypes($filterNode, \%filterHash);
    my $dimensionalitiesAreSpecified = findAllowedDimensionalities($filterNode, \%filterHash); 
    
    #ONLY execute if there are no allowed datatypes/dimensionalities specified 
    # OR the datatype/dimensionality provided is listed as one of the allowed datatypes/dimensionalities
    if ( ( $datatypesAreSpecified == 0 || 
           ($datatypesAreSpecified == 1 && isAllowedDatatype($inputPixeltype, \%filterHash)) ) &&
         ( $dimensionalitiesAreSpecified == 0 || 
           ($dimensionalitiesAreSpecified == 1 && isAllowedDimensionality($dimensionality, \%filterHash)) ) ){
        
        # Extract the filter names 
        my ($returnStatus, $filterName) = findFilterName($filterNode, \%filterHash, $inputPixeltype);
        if ( $returnStatus == 0 ) { 
            die "ERROR: No 'Name' element found for filter " . ($filterInd+1);
        }
        if ($filterInd < $numTransforms) {
            $filterNameList = $filterNameList . substr($filterName, 0, length($filterName) - 4) . 
            $dimensionality . "D;";
        }
        else {
            $filterNameList = $filterNameList . $filterName;
        }
        
        #if the GENERATE flag is set, extract filter information, store in hash, and generate all source code
        if ($flag eq "-GENERATE"){
            if( !findTemplateParameters($filterNode, \%filterHash) ) {
                die "ERROR: No indication of Template Parameters for filter " . 
                    ($filterInd+1);
            }
            if ( !findInput($filterNode, \%filterHash) ) {
                die "ERROR: 'Input' element with invalid 'Input_Name' found for filter " . 
                    ($filterInd+1);
            }  
            if ( !findFilterParameters($filterNode, \%filterHash) ) {
                die "ERROR: Invalid Parameter element found for filter " . 
                    ($filterInd+1); 
            }
            if ( !findOutput($filterNode, \%filterHash) ) { 
                die "ERROR: 'Output' element with invalid 'Output_Name' found for filter " . 
                    ($filterInd+1);
            }
            
            if ($filterInd < $numTransforms) {
                # Generate the .tpp file and S-Function code for transforms
                TPPGen(\%filterHash, $dimensionality, $directory, "TransformFilterBlock.tpp.in");
                SFunctionGen(\%filterHash, $dimensionality, $inputPixeltype, $outputPixeltype,
                  $directory, "TransformFilterBlockMat.cpp.in");
                
                # Add Mask code for the transforms
                # A library separate from the other filters is created for transforms because they are not specific to pixeltype
                my $transformMask;
                (\%filterHash)->{"Name"} = 
                  substr((\%filterHash)->{"Name"},0,length((\%filterHash)->{"Name"}) - 3) . $dimensionality . "D";
                if ($transformOnLeftColumn == 1){
                    $transformMask = FilterMaskGen(\%filterHash, \%transformPositionLeftCol);
                    $transformPositionLeftCol{"top"} += 70;
                    $transformPositionLeftCol{"bottom"} += 70;
                    $transformOnLeftColumn = 0;
                }else{
                    $transformMask = FilterMaskGen(\%filterHash, \%transformPositionRightCol);
                    $transformPositionRightCol{"top"} += 70;
                    $transformPositionRightCol{"bottom"} += 70;
                    $transformOnLeftColumn = 1;
                }
                $transformMaskContent = $transformMaskContent . $transformMask;
            }
            # Generate the .tpp file and S-Function code for interpolators
            elsif ($filterInd < $numTransforms + $numInterpolators) {
                TPPGen(\%filterHash, $dimensionality, $directory, "InterpolatorFilterBlock.tpp.in");
                SFunctionGen(\%filterHash, $dimensionality, $inputPixeltype, $outputPixeltype,
                $directory, "InterpolatorFilterBlockMat.cpp.in");
                
                #Add Mask code for the interpolator, increment the positions for the filter  masks
                my $filterMask;
                if ($onLeftColumn == 1){
                    $positionLeftCol{"bottom"} += 70;
                    $filterMask = FilterMaskGen(\%filterHash, \%positionLeftCol);
                    $positionLeftCol{"top"} += 70;
                    $onLeftColumn = 0;
                    
                    # If this is the last interpolator, start the next group of blocks on a new line
                    if ($filterInd == $numTransforms + $numInterpolators - 1) {
                      $positionRightCol{"bottom"} += 70;
                      $positionRightCol{"top"} += 70;
                      $onLeftColumn = 1;
                    }
                    
                }else{
                    $positionRightCol{"bottom"} += 70;
                    $filterMask = FilterMaskGen(\%filterHash, \%positionRightCol);
                    $positionRightCol{"top"} += 70;
                    $onLeftColumn = 1;
                }
                $maskContent = $maskContent . $filterMask;
            }
            # Generate the .tpp file and S-Function code for normal filters
            else {
                TPPGen(\%filterHash, $dimensionality, $directory, "FilterBlock.tpp.in");
                SFunctionGen(\%filterHash, $dimensionality, $inputPixeltype, $outputPixeltype,
                  $directory, "FilterBlockMat.cpp.in");
                
                #Add Mask code for the filter, increment the positions for the filter  masks
                my $filterMask;
                if ($onLeftColumn == 1){
                    $positionLeftCol{"bottom"} += 100;
                    $filterMask = FilterMaskGen(\%filterHash, \%positionLeftCol);
                    $positionLeftCol{"top"} += 100;
                    $onLeftColumn = 0;
                }else{
                    $positionRightCol{"bottom"} += 100;
                    $filterMask = FilterMaskGen(\%filterHash, \%positionRightCol);
                    $positionRightCol{"top"} += 100;
                    $onLeftColumn = 1;
                }
                $maskContent = $maskContent . $filterMask;
            }
        }
    }
}

my $datatypeID = datatypeCode($inputPixeltype) . $dimensionality;

#Generates the filter and transform libraries
if ($flag eq "-GENERATE"){
    if ($numFilters + $numInterpolators > 0) {
        LibraryGen($dimensionality, $inputPixeltype, $datatypeID, $maskContent, $directory, "Library.mdl.in");
    }
    if ($numTransforms > 0) {
        LibraryGen($dimensionality, $inputPixeltype, $datatypeID, $transformMaskContent, $directory, "TransformLibrary.mdl.in");
    }
}

#Generates the base classes supporting the filters once.  These include VirtualPort.h, VirtualBlock.h, VirtualSpecialPort.h, 
#ImageConversion.h and ImageConversion.tpp
if ($flag eq "-GENERATE"){
    BaseClassCopy($directory);
}

if ($flag eq "-LIST"){
    chop($filterNameList);
    print $filterNameList;
}

$doc->dispose;

##########################################################
# datatypeCode
# Converts a datatype string into a two-letter code.
#
# Input: datatype string
# Returns: Two-letter datatype code
#              Empty string if the input datatype is unrecognized
##########################################################
sub datatypeCode {
  my $datatype = shift;
  switch ($datatype) {
    case "float" { return "FL"; }
    case "char" { return "SC"; }
    case "unsigned char" { return "UC"; }
    case "short" { return "SS"; }
    case "unsigned short" { return "US"; }
    else    { return ""; }
  }
}

##########################################################
# findFilterName
# Extracts Name for the filter, adds a three-character suffix consisting of a two-letter 
# datatype code and a one-digit dimensionality, and stores it as a scalar in %filterHash
#
# Input: 1. an XML::DOM::NodeList
#          2. reference to %filterHash
#          3. Input pixel type
#          4. $flag
# Returns: False and empty string if a Name element is not found
#              Else true and the filter name with a succeeding semicolon
#           
# If $flag is set to -LIST, prints a list of the filter names to standard output
##########################################################
sub findFilterName {

  my ($filterNode, $filterHash, $inputPixeltype) = @_;
  
  if ($filterNode->getElementsByTagName("Name")->getLength <= 0) {
    return (0, "");
  }

  $filterHash->{"Name"} = 
    $filterNode->getElementsByTagName("Name")->item(0)->
      getFirstChild->getNodeValue . datatypeCode($inputPixeltype) .
      $dimensionality;
 
  my $filterName = $filterHash->{"Name"} . ";";
  return (1, $filterName);
}

##########################################################
# findTemplateParameters
# Extracts the template parameters for the filter
#
# Input: 1. an XML::DOM::NodeList
#          2. reference to %filterHash
# Returns: False if a Template_Parameters element is not found
#              Else true
#
# If $flag is set to -LIST, prints a list of the filter names to standard output
##########################################################
sub findTemplateParameters {
  
  my ($filterNode, $filterHash) = @_;

  if ($filterNode->getElementsByTagName("Template_Parameters")->getLength > 0) {
    my $templateParameterNodes = $filterNode->getElementsByTagName("Template_Parameters")->
      item(0)->getElementsByTagName("Template_Parameter");

    if ($templateParameterNodes->getLength > 0) {
      my $numTemplateParameters = $templateParameterNodes->getLength;
      for (my $i=0; $i < $numTemplateParameters; $i++) {
        $filterHash->{"Template_Parameters"}->[$i] = $templateParameterNodes->item($i)->
        getFirstChild->getNodeValue;
      }
      return 1;
    }
  }
  return 0;
}
##########################################################
# findAllowedDatatypes
# Extracts any Allowed_Datatypes for the filter and stores
# them as an array in %filterHash
#
# Input: 1. an XML::DOM::NodeList
#          2. reference to %filterHash
# Returns: True if there have been allowed datatypes specified, false otherwise.
##########################################################
sub findAllowedDatatypes {

  my ($filterNode, $filterHash) = @_;

  if ($filterNode->getElementsByTagName("Allowed_Datatypes")->getLength > 0) {
    my $datatypeNodes = $filterNode->getElementsByTagName("Allowed_Datatypes")->
      item(0)->getElementsByTagName("Datatype");
    
    if ($datatypeNodes->getLength > 0) {
      my $numAllowedDatatypes = $datatypeNodes->getLength;
      for (my $i=0; $i < $numAllowedDatatypes; $i++) {
        $filterHash->{"Allowed_Datatypes"}->[$i] = $datatypeNodes->item($i)->
        getFirstChild->getNodeValue;
      }
    }    
  }else{ #if no allowed datatypes were specified, assume all are allowed
    return 0;
  }
  return 1;
}
##########################################################
# isAllowedDatatype
# Checks to see if the datatype requested for the filter pixel type is an allowed datatype. 
#
# Input: 1. pixel type
#          2. reference to %filterHash
# Returns: True if the datatype is allowed and false otherwise
##########################################################
sub isAllowedDatatype{
  my ($pixeltype, $filterHash) = @_;
  
  foreach my $datatype ( @{$filterHash->{"Allowed_Datatypes"}} ) {
    if ($pixeltype eq $datatype){
        return 1; 
    }
  }
  return 0;
}

##########################################################
# findAllowedDimensionalities
# Extracts any Allowed_Dimensionalities for the filter and stores
# them as an array in %filterHash
#
# Input: 1. an XML::DOM::NodeList
#          2. reference to %filterHash
# Returns: True if there have been allowed dimensionalities specified, false otherwise.
##########################################################
sub findAllowedDimensionalities {

  my ($filterNode, $filterHash) = @_;

  if ($filterNode->getElementsByTagName("Allowed_Dimensionalities")->getLength > 0) {
    my $dimensionalityNodes = $filterNode->getElementsByTagName("Allowed_Dimensionalities")->
      item(0)->getElementsByTagName("Dimensionality");

    if ($dimensionalityNodes->getLength > 0) {
      my $numDimensionalities = $dimensionalityNodes->getLength;
      for (my $i=0; $i < $numDimensionalities; $i++) {
        $filterHash->{"Allowed_Dimensionalities"}->[$i] = $dimensionalityNodes->item($i)->
        getFirstChild->getNodeValue;
      }
    }
  }else{ #if no allowed dimensionalities were specified, assume all are allowed
    return 0;
  }
  return 1;
}

##########################################################
# isAllowedDimensionality
# Checks to see if the dimensionalitiy requested for the filter is an allowed dimensionality. 
#
# Input: 1. dimensionality
#          2. reference to %filterHash
# Returns: True if the dimensionality is allowed and false otherwise
##########################################################
sub isAllowedDimensionality{
  my ($dimensionality, $filterHash) = @_;
  
  foreach my $allowedDimensionality ( @{$filterHash->{"Allowed_Dimensionalities"}} ) {
    if ($dimensionality eq $allowedDimensionality){
        return 1; 
    }
  }
  return 0;
}

##########################################################
# findInput
# Extracts the Inputs for the filter and stores them as
# an array of hashes in %filterHash
#
# Input: 1. an XML::DOM::NodeList
#          2. reference to %filterHash
# Returns: False if an input is found with no Input_Name
#             Else true
##########################################################
sub findInput {

  my ($filterNode, $filterHash) = @_;
  
  if ($filterNode->getElementsByTagName("Inputs")->getLength > 0) {
    my $numInputs = $filterNode->getElementsByTagName("Inputs")->item(0)->
      getElementsByTagName("Input")->getLength;
    if ($numInputs <= 0) {
      return 1;
    }

    my $inputNodes = $filterNode->getElementsByTagName("Inputs")->item(0)->
      getElementsByTagName("Input");
    for (my $i=0; $i < $numInputs; $i++) {
      my $inputNames = $inputNodes->item($i)->getElementsByTagName("Input_Name");
      if ($inputNames->getLength <= 0) {
        return 0;
      }

      $filterHash->{"Inputs"}->[$i]->{"Input_Name"} = $inputNames->item(0)->
        getFirstChild->getNodeValue;

      # Set input type and dimension if necessary
      if ($inputNodes->item($i)->getElementsByTagName("Input_Type")->getLength > 0) {
        $filterHash->{"Inputs"}->[$i]->{"Input_Type"} = $inputNodes->item($i)->
          getElementsByTagName("Input_Type")->item(0)->getFirstChild->getNodeValue;
      }
      if ($inputNodes->item($i)->getElementsByTagName("Input_Dimension")->getLength > 0) {
        $filterHash->{"Inputs"}->[$i]->{"Input_Dimension"} = $inputNodes->item($i)->
          getElementsByTagName("Input_Dimension")->item(0)->getFirstChild->getNodeValue;
      }
    }
  }
  return 1;
}
  
##########################################################
# findFilterParameters
# Extracts the Parameters for the filter and stores 
# them as an array of hashes in %filterHash.
# A separate array of hashes is created in %filterHash for Special Inputs. Special Inputs include
# parameters who have an ITK_Parameter_Type of: NodeContainer, TransformType. These parameters are not stored
# with the other parameters.
#
# Input: 1. an XML::DOM::NodeList
#          2. reference to %filterHash
# Returns: False if a parameter does not have a Parameter_Name, Parameter_Type or 
#                 ITK_Parameter_Type or Eunum_Parameter_Type, and Parameter_Size
#             Else true
##########################################################
sub findFilterParameters {

  my ($filterNode, $filterHash) = @_;

  if ($filterNode->getElementsByTagName("Parameters")->getLength > 0) {
    my $parameterNodes = $filterNode->getElementsByTagName("Parameters")->item(0)->
      getElementsByTagName("Parameter");
    my $numParameters = $parameterNodes->getLength;

    my $normalParamCount = 0;
    my $specialInputCount = 0;
    # Process each parameter in turn
    for (my $i=0; $i < $numParameters; $i++) {
    
      my $parameterType = $parameterNodes->item($i)->getElementsByTagName("Parameter_Type");
      my $ITKParameterType = $parameterNodes->item($i)->getElementsByTagName("ITK_Parameter_Type");
      my $enumParameterType = $parameterNodes->item($i)->getElementsByTagName("Enum_Parameter_Type");
      
      # If the ITK_Parameter_Type is a "special type", it is stored in a separate array within %filterHash
      if ($ITKParameterType->getLength > 0 && 
        ($ITKParameterType->item(0)->getFirstChild->getNodeValue eq "NodeContainer" ||
        $ITKParameterType->item(0)->getFirstChild->getNodeValue eq "InterpolatorType" ||
        $ITKParameterType->item(0)->getFirstChild->getNodeValue eq "TransformType")) {
          
        # Set Special_Input_Name
        my $specialInputName = $parameterNodes->item($i)->getElementsByTagName("Parameter_Name");
        if ($specialInputName->getLength <= 0) {
          return 0;
        }
        $filterHash->{"Special_Inputs"}->[$specialInputCount]->{"Special_Input_Name"} = $specialInputName->
          item(0)->getFirstChild->getNodeValue;
        
        # Set ITK_Parameter_Type
        $filterHash->{"Special_Inputs"}->[$specialInputCount]->{"ITK_Parameter_Type"} = $ITKParameterType->
          item(0)->getFirstChild->getNodeValue;
        
        $specialInputCount++;
      }
      # Else process the parameter as a normal parameter
      else {
      
        #  Set Parameter_Name
        my $parameterName = $parameterNodes->item($i)->getElementsByTagName("Parameter_Name");
        if ($parameterName->getLength <= 0) {
          return 0;
        }
        $filterHash->{"Parameters"}->[$normalParamCount]->{"Parameter_Name"} = $parameterName->
          item(0)->getFirstChild->getNodeValue;

        # Set Parameter_Type and/or ITK_Parameter_Type and/or Enum_Parameter_Type. At least one must be set.
        if ($parameterType->getLength > 0) {
          $filterHash->{"Parameters"}->[$normalParamCount]->{"Parameter_Type"} = $parameterType->
          item(0)->getFirstChild->getNodeValue;
        }
        if ($ITKParameterType->getLength > 0) {
          $filterHash->{"Parameters"}->[$normalParamCount]->{"ITK_Parameter_Type"} = $ITKParameterType->
          item(0)->getFirstChild->getNodeValue;
        }
        if ($enumParameterType->getLength > 0) {
          $filterHash->{"Parameters"}->[$normalParamCount]->{"Enum_Parameter_Type"} = $enumParameterType->
          item(0)->getFirstChild->getNodeValue;
        } 
        if ($parameterType->getLength <= 0 && $ITKParameterType->getLength <= 0 && 
          $enumParameterType->getLength <= 0) {
          return 0;
        }

        # Set Parameter_Size
        my $parameterSize = $parameterNodes->item($i)->getElementsByTagName("Parameter_Size");
        if ($parameterSize->getLength <= 0) {
          return 0;
        }
        $filterHash->{"Parameters"}->[$normalParamCount]->{"Parameter_Size"} = $parameterSize->
          item(0)->getFirstChild->getNodeValue;
        
        $normalParamCount++;
      }
    }
  }
  return 1;
}

##########################################################
# findOutput
# Extracts the Outputs for the filter and stores them as
# an array of hashes in %filterHash
#
# Input: 1. an XML::DOM::NodeList
#        2. reference to %filterHash
# Returns: False an output is found with no Output_Name
#             Else true
##########################################################
sub findOutput {

  my ($filterNode, $filterHash) = @_;

  if ($filterNode->getElementsByTagName("Outputs")->getLength > 0) {
    my $numOutputs = $filterNode->getElementsByTagName("Outputs")->item(0)->
      getElementsByTagName("Output")->getLength;
    if ($numOutputs <= 0) {
      return 1;
    }
  
    my $outputNodes = $filterNode->getElementsByTagName("Outputs")->item(0)->
      getElementsByTagName("Output");
    for (my $i=0; $i < $numOutputs; $i++) {
      my $outputNames = $outputNodes->item($i)->getElementsByTagName("Output_Name");
      if ($outputNames->getLength <= 0) {
        return 0;
      }

      $filterHash->{"Outputs"}->[$i]->{"Output_Name"} = $outputNames->item(0)->
        getFirstChild->getNodeValue;

      # Set output type and dimension if necessary
      if ($outputNodes->item($i)->getElementsByTagName("Output_Type")->getLength > 0) {
        $filterHash->{"Outputs"}->[$i]->{"Output_Type"} = $outputNodes->item($i)->
          getElementsByTagName("Output_Type")->item(0)->getFirstChild->getNodeValue;
      }
      if ($outputNodes->item($i)->getElementsByTagName("Output_Dimension")->getLength > 0) {
        $filterHash->{"Outputs"}->[$i]->{"Output_Dimension"} = $outputNodes->item($i)->
          getElementsByTagName("Output_Dimension")->item(0)->getFirstChild->getNodeValue;
      }
    }
  }
  return 1;
}
