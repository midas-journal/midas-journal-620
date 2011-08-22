package vtkFilterMaskGen;


# =================
# Copyright (c) Queen's University
# All rights reserved.

# See Copyright.txt for more details.
# =================

###############################################
# SIMITK Project
# Karen Li and Jing Xiang
# May 26, 2008
#
# FilterMaskGen.pm
#
# Modified by Adam for use with SIMVTK on June 5th 2008
###############################################

use strict;
use Switch;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(vtkFilterMaskGen);

##########################################################
# FilterMaskGen subroutine
# Generates the code for a S-function mask that corresponds to one filter. 
#
# Input: 1. reference to %filterHash
#	    2. position of where the filter mask should go in the library
# Returns: Mask code for the current filter.
##########################################################
sub vtkFilterMaskGen {

#CHANGE HERE2! (get the alg sub hash)
  my ($filterHash, $position, $sourceDirectory, $algorithmSubclassesHash) = @_;
  
  die "ERROR: vtkFilterMask.in file not found"
  unless -f $sourceDirectory . "/vtkFilterMask.in";
  
  open (INFILE, "<", $sourceDirectory . "/vtkFilterMask.in");

  undef $/;
  my $content = <INFILE>;
  
  $/ = "\n";
  close INFILE;
  
  # if is not on Windows, remove the control-M characters
  if ($^O ne "MSWin32") {
    $content =~ s/\cM//g;
  }
  
  # FILTER_NAME  
  my $filterName = $filterHash->{"Filter_Name"};
  $content =~ s/\@FILTER_NAME\@/$filterName/g;
 
  # NUM_INPUT_PORTS
   my $numInputs = 0;
  $numInputs = scalar @{$filterHash->{"Inputs"}} if $filterHash->{"Inputs"};
  my $numInputPorts = 1; #just using self for now
  $content =~ s/\@NUM_INPUT_PORTS\@/$numInputPorts/g;
  
  # NUM_OUTPUT_PORTS 
    my $numOutputs = 0;
  $numOutputs = scalar @{$filterHash->{"Outputs"}} if $filterHash->{"Outputs"};
  my $numOutputPorts = 1; #just using self for now
  $content =~ s/\@NUM_OUTPUT_PORTS\@/$numOutputPorts/g;
 
  #POSITION
  my $left = $position->{"left"};
  $content =~ s/\@LEFT\@/$left/g;
  my $top = $position->{"top"};
  $content =~ s/\@TOP\@/$top/g;
  my $right = $position->{"right"};
  $content =~ s/\@RIGHT\@/$right/g;
  my $bottom = $position->{"bottom"};
  $content =~ s/\@BOTTOM\@/$bottom/g;
  
  #FILTER_PARAMETERS  
  
  my $filterParametersString = getFilterParametersString($filterHash);
  $content =~ s/\@FILTER_PARAMETERS\@/$filterParametersString/g;
   
  #MASK_PROMPT_STRING 
  my $maskPromptString = getMaskPromptString($filterHash);
  $content =~ s/\@MASK_PROMPT_STRING\@/$maskPromptString/g;
  
  #MASK_STYLE_STRING  
  my $maskStyleString = getMaskStyleString($filterHash);
  $content =~ s/\@MASK_STYLE_STRING\@/$maskStyleString/g;
  
  #MASK_TUNABLE_VALUE_STRING   
  my $maskOnString = getMaskOnString($filterHash);
  $content =~ s/\@MASK_TUNABLE_VALUE_STRING\@/$maskOnString/g;
  
  #MASK_CALLBACK_STRING  
   my $maskCallbackString = getMaskCallbackString($filterHash);
  $content =~ s/\@MASK_CALLBACK_STRING\@/$maskCallbackString/g;
  
  #MASK_ENABLE_STRING 
   $content =~ s/\@MASK_ENABLE_STRING\@/$maskOnString/g;
   
  #MASK_VISIBILITY_STRING   
   $content =~ s/\@MASK_VISIBILITY_STRING\@/$maskOnString/g;
   
  #MASK_TOOL_TIP_STRING 
   $content =~ s/\@MASK_TOOL_TIP_STRING\@/$maskOnString/g;
  
  #MASK_VAR_ALIAS_STRING
  my $maskCommaString = getMaskCommaString($filterHash);
  $content =~ s/\@MASK_VAR_ALIAS_STRING\@/$maskCommaString/g;
  
  #MASK_VARIABLES 
  my $maskVariables = getMaskVariables($filterHash);
  $content =~ s/\@MASK_VARIABLES\@/$maskVariables/g;
  
  #MASK_DISPLAY  
  my $maskDisplay = getMaskDisplay($filterHash);
  $content =~ s/\@MASK_DISPLAY\@/$maskDisplay/g;
  
  #MASK_VALUE_STRING  
  #CHANGE HERE2! (pass along alg sub hash)
  my $maskValueString = getMaskValueString($filterHash, $algorithmSubclassesHash);
  $content =~ s/\@MASK_VALUE_STRING\@/$maskValueString/g;
  
  #MASK_TAB_NAME_STRING 
  $content =~ s/\@MASK_TAB_NAME_STRING\@/$maskCommaString/g;

  return $content;
}

##########################################################
# getFilterParametersString
# gets the parameters of a filter and creates a string for the mask code. 
# ex: "Inputs, ParameterIndicator,ParameterOutput,Parameter,Output"
##########################################################
sub getFilterParametersString{
  my $filterHash = shift;
  my $string = "\"";
  
  $string = $string . getFilterParametersInputString($filterHash);
  $string = $string . getFilterParametersParameterString($filterHash);
  $string = $string . getFilterParametersOutputString($filterHash);
  
  chop($string); #removes the last character ","
  $string = $string . "\"";  #  now remove last ',' and add " since this is the last step
  return $string;
}

##########################################################
#getFilterParametersInputString
#gets the input names of a filter for the mask code as the first elements in the mask
##########################################################
sub getFilterParametersInputString{
  my $filterHash= shift;
  my $string;
  
  foreach my $input (@{$filterHash->{"Inputs"}} ){
    my $inputName = $input->{"Input_Name"};
    $string = $string . "VTKInput" . $inputName . ",";
  }
  # do not remove last ',' or add " since this is only the first part of a multi-step process to make the string 
  return $string;
}

##########################################################
#getFilterParametersParamterString
#gets the parameter names of a filter for the mask code as the first elements in the mask as well
#as putting an indicator variable before each for input and one for output
##########################################################
sub getFilterParametersParameterString{
  my $filterHash= shift;
  my $string;
  
  foreach my $param (@{$filterHash->{"Filter_Parameters"}} ){
    my $paramName = $param->{"Parameter_Name"};
    
    #CHANGE HERE! (just remove the middle line)
    $string = $string . $paramName . "InputIndicator," .
    "VTKParam" . $paramName . ",";
  }
  # do not remove last ',' or add " since this is only the second part of a multi-step process to make the string 
  return $string;
}

##########################################################
#getFilterParametersOutputString
#gets the output names of a filter for the mask code as the first elements in the mask 
##########################################################
sub getFilterParametersOutputString{
  my $filterHash= shift;
  my $string;
  
  foreach my $output (@{$filterHash->{"Outputs"}} ){
    my $outputName = $output->{"Output_Name"};
    $string = $string . "VTKOutput" . $outputName . ",";
  }
  return $string;
}

##########################################################
#getMaskPromptString
# gets the parameters of a filter and creates a string for the mask code that the user will see in mask dialog
# box. 
# ex: "Input|ParameterUseIndicator|Parameter|Output"
##########################################################
sub getMaskPromptString{
  my $filterHash = shift;
  my $string = "\"";
  
  $string = $string . getMaskPromptInputString($filterHash);
  $string = $string . getMaskPromptParameterString($filterHash);
  $string = $string . getMaskPromptOutputString($filterHash);
  
  chop($string); #removes the last character "|"
  $string = $string . "\"";  #  now remove last '|' and add " since this is the last step
  return $string;
}

##########################################################
#getMaskPromptInputString
#gets the input names of a filter for the mask code as the first elements in the mask
##########################################################
sub getMaskPromptInputString{
  my $filterHash= shift;
  my $string;
  
  foreach my $input (@{$filterHash->{"Inputs"}} ){
    my $inputName = $input->{"Input_Name"};
    my $inputFlags = $input->{"Input_Flags"};
    if ( $inputFlags eq "Optional" ){	
      $string = $string . $inputName . " as Input|";
    }
    elsif ($inputFlags eq "Repeatable,Optional"){
      $string = $string . $inputName . " Inputs|";
    }
  }
  # do not remove last '|' or add " since this is only the first part of a multi-step process to make the string 
  return $string;
}

##########################################################
#getMaskPromptParamterString
#gets the parameter names of a filter for the mask code as the first elements in the mask as well
#as putting an indicator variable before each for input and one for output
##########################################################
sub getMaskPromptParameterString{
  my $filterHash= shift;
  my $string;
  
  foreach my $param (@{$filterHash->{"Filter_Parameters"}} ){
    my $paramName = $param->{"Parameter_Name"};
    #CHANGE HERE! (remove the as Output , and change Indicator to Parameter)
    $string = $string . $paramName . " Parameter|" .
    $paramName . " Value|" ;
  }
  # do not remove last '|' or add " since this is only the second part of a multi-step process to make the string 
  return $string;
}

##########################################################
#getMaskPromptOutputString
#gets the output names of a filter for the mask code as the first elements in the mask 
##########################################################
sub getMaskPromptOutputString{
  my $filterHash= shift;
  my $string;
  
  my $filterName = $filterHash->{"Filter_Name"};
  foreach my $output (@{$filterHash->{"Outputs"}} ){
    my $outputName = $output->{"Output_Name"};
    if ("Self" eq  $outputName){
      $string = $string . "Self as Output|";
      }
    else {
      $string = $string . $outputName . " as Output|";
    }
  }
  return $string;
}

##########################################################
# getMaskStyleString
# further subdivided to seperate the inputs from the parameters from the outputs.
# inputs are either checkbox (optional) or edit (repeatable) or dropdown (parameter input indicator)
# parameters are checkbox for indicators and edit for actual parameter
# outputs are checkbox
# ex: "popup|checkbox|edit"
##########################################################
sub getMaskStyleString{
  my $filterHash = shift;
  my $string = "\"";
  
  $string = $string . getMaskStyleInputString($filterHash);
  $string = $string . getMaskStyleParameterString($filterHash);
  $string = $string . getMaskStyleOutputString($filterHash);
  
  chop($string); #removes the last character ","
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskStyleInputString
# ex: "edit|checkbox|edit"
##########################################################
sub getMaskStyleInputString{
  my $filterHash = shift;
  my $string;
  
  foreach my $input (@{$filterHash->{"Inputs"}} ){
    my $inputName = $input->{"Input_Name"};
    my $inputFlags = $input->{"Input_Flags"};
    if ( $inputFlags eq "Optional" ){	
      $string = $string . "checkbox,";
    }
    elsif ($inputFlags eq "Repeatable,Optional"){
      $string = $string . "edit,";
    }
  }
  # do not remove last '|' or add " since this is only the first part of a multi-step process to make the string 
  return $string;
}

##########################################################
# getMaskStyleParameterString
# ex: "popup|checkbox|edit|..."
##########################################################
sub getMaskStyleParameterString{
  my $filterHash = shift;
  my $string;

  my $numParameters = scalar @{$filterHash->{"Filter_Parameters"}} if $filterHash->{"Filter_Parameters"};
  
  for (my $i = 0; $i < $numParameters; $i++){
  #CHANGE HERE! (change to add As Output at the end)
  $string = $string . "popup(As Parameter|As Input|Use Default|As Output),edit,";
  }
  return $string;
}

##########################################################
# getMaskStyleOutputString
# ex: "checkbox|checkbox|checkbox|...."
##########################################################
sub getMaskStyleOutputString{
  my $filterHash = shift;
  my $string;
  
  my $numOutput = scalar @{$filterHash->{"Outputs"}} if $filterHash->{"Outputs"};
  
  for (my $i = 0; $i < $numOutput; $i++){
  $string = $string . "checkbox,";
  }

  return $string;
}

##########################################################
#getMaskCallbackString
# return a string of callbacks for each Matlab parameter
# ex: "vtkFilterCallback(Parameter1NameCallback, gcb)|vtkFilterCallback(Parameter2NameCallback, gcb)|..."
##########################################################
sub getMaskCallbackString{
  my $filterHash = shift;
  my $string = "\"";
  
  $string = $string . getMaskCallbackInputString($filterHash);
  $string = $string . getMaskCallbackParameterString($filterHash);
  $string = $string . getMaskCallbackOutputString($filterHash);
  
  chop($string);  # remove last character
  $string = $string . "\"";  # add quote at end
  
  return $string;
}

##########################################################
#getMaskCallbackInputString
# return a string of callbacks for each input
##########################################################
sub getMaskCallbackInputString{
  my $filterHash = shift;
  my $string = "";
  
  my $filterName = $filterHash->{"Filter_Name"};
  foreach my $input (@{$filterHash->{"Inputs"}} ){
    my $inputName = $input->{"Input_Name"};
    $string = $string . "Sim" . $filterName . "Callback('VTKInput" . $inputName . "Callback',gcb)|";
  }
  # basically go through all inputs and do replace proper vtkFilter name infront of callback,
  # then make it input name Callback,gcb) 
  return $string;
}

##########################################################
#getMaskCallbackParameterString
# return a string of callbacks for each XML parameter
##########################################################
sub getMaskCallbackParameterString{
  my $filterHash = shift;
  my $string = "";
  
  my $filterName = $filterHash->{"Filter_Name"};
  foreach my $parameter (@{$filterHash->{"Filter_Parameters"}}){
    my $parameterName = $parameter->{"Parameter_Name"};
    #first add a callback for the input indicator
    $string = $string . "Sim" .$filterName . "Callback('" . $parameterName . "InputIndicatorCallback',gcb)|";
    #then add a callback for the output indicator
    #CHANGE HERE! (remove this next line)
    #then add a callback for the parameter
    $string = $string . "Sim" . $filterName . "Callback('VTKParam" . $parameterName . "Callback',gcb)|";
  }
  
  # basically go through all paramter and do replace proper vtkFilter name infront of callback,
  # then make it paramter name Callback,gcb) 
  # then do the same except make 
  return $string;
}

##########################################################
#getMaskCallbackString
# return a string of callbacks for each output
##########################################################
sub getMaskCallbackOutputString{
  my $filterHash = shift;
  my $string = "";
  
  my $filterName = $filterHash->{"Filter_Name"};
  foreach my $output (@{$filterHash->{"Outputs"}} ){
    my $outputName = $output->{"Output_Name"};
    $string = $string . "Sim" . $filterName . "Callback('VTKOutput" . $outputName . "Callback',gcb)|";
  }
  
  # basically go through all outputs and do replace proper vtkFilter name infront of callback,
  # then make it output name Callback,gcb) 
  return $string;
}

##########################################################
# getMaskOnString
# want one 'On' for each input, 2 for each parameter and 1 for each output
# ex: "On|On|On"
# note: This string is reused for more than one field in the filter mask code. 
##########################################################
sub getMaskOnString{
  my $filterHash = shift;
  my $string = "\"";
  
  my $numParameters = scalar @{$filterHash->{"Filter_Parameters"}} if $filterHash->{"Filter_Parameters"};
  my $numInputs =  scalar @{$filterHash->{"Inputs"}} if $filterHash->{"Inputs"};
  my $numOutputs =  scalar @{$filterHash->{"Outputs"}} if $filterHash->{"Outputs"};
  
  #CHANGE HERE! (make the 3 into a 2 again)
  for ( my $i = 0; $i <  ($numParameters * 2 + $numInputs + $numOutputs);  $i++ ){
  $string = $string . "on,";
  }
  chop($string); #removes the last character ","
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskCommaString
# ex: ",,"
# note: This string is reused for more than one field in the filter mask code. 
##########################################################
sub getMaskCommaString{
  my $filterHash = shift;
  my $string = "\"";
  
  my $numParameters = scalar @{$filterHash->{"Filter_Parameters"}} if $filterHash->{"Filter_Parameters"};
  my $numInputs =  scalar @{$filterHash->{"Inputs"}} if $filterHash->{"Inputs"};
  my $numOutputs =  scalar @{$filterHash->{"Outputs"}} if $filterHash->{"Outputs"};
  
  #CHANGE HERE!  (make the 3 into a 2 again)
  for (my $i = 0; $i < ($numParameters * 2 + $numInputs + $numOutputs); $i++){
  $string = $string . ",";
  }
  chop($string); #removes the last character ","
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskVariables
# ex: "Input=@1;ParameterInput=@2;ParameterOutput=@3;Parameter=@4;..."
##########################################################
sub getMaskVariables{
  my $filterHash = shift;
  my $string = "\"";
  my $count = 1;
  
  foreach my $input ( @{$filterHash->{"Inputs"}} ) {
    my $inputName = $input->{"Input_Name"};
  $string = $string . "VTKInput" . $inputName . "=@" . $count . ";";
  $count++;
  }
  
  foreach my $param ( @{$filterHash->{"Filter_Parameters"}} ) {
    my $paramName = $param->{"Parameter_Name"};
  $string = $string . $paramName . "InputIndicator". "=@" . $count . ";";
  $count++;
  #CHANGE HERE! (remove the OutputIndicator stuff)
  $string = $string . "VTKParam" . $paramName . "=@" . $count . ";";
  $count++;
  }
  
  foreach my $output ( @{$filterHash->{"Outputs"}} ) {
    my $outputName = $output->{"Output_Name"};
  $string = $string . "VTKOutput" . $outputName . "=@" . $count . ";";
  $count++;
  }
  
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskDisplay
# will only display those inputs/outputs that are part of the XML file as it is not instantiated to check
# for any vtkAlgorithmOutput types.
##########################################################
sub getMaskDisplay{
  my $filterHash = shift;
  my $string = "\"";
  my $portNum = 1;
  
  # will not label any ports that come from the vtkObject itself
  
  foreach my $input ( @{$filterHash->{"Inputs"}} ) {
    my $inputName = $input->{"Input_Name"};
  $string = $string . "port_label('input',". $portNum . ",'" . $inputName . "');\\n";
  $portNum++;
  }
  
  $portNum = 1;
  
  my $filterName = $filterHash->{"Filter_Name"};
  
  foreach my $output ( @{$filterHash->{"Outputs"}} ) {
    my $outputName = $output->{"Output_Name"};
  if ( $outputName eq "Self") {
    $string = $string . "port_label('output',". $portNum . ",'Self');\\n";
  }
  else {	
    $string = $string . "port_label('output',". $portNum . ",'" . $outputName . "');\\n";
  }
  $portNum++;
  }
  
  $string .= "\"";
  
  return $string;
}

##########################################################
# getMaskValueString
# optional inputs start as on.
# repeatable inputs start as 1.
# parameters start as : Use Default, off, 0. (will change to have real defaults later)
# outputs start as on.
# ex: "on|off|0|off|0|on"
##########################################################
sub getMaskValueString{
  my $filterHash = shift;
  my $algorithmSubclassesHash = shift;
  my $string = "\"";
  
  $string .= getMaskValueInputString($filterHash, $algorithmSubclassesHash);
  $string .= getMaskValueParameterString($filterHash);
  #CHANGE HERE2! (make the last one also take the alg subclass hash)
  $string .= getMaskValueOutputString($filterHash, $algorithmSubclassesHash);
  chop($string); #removes the last character "|"
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskValueInputString
# ex: "on|on|on"
##########################################################
sub getMaskValueInputString{
  my $filterHash = shift;
  my $algorithmSubclassesHash = shift;
  my $string = "";
  
  #CHANGE HERE2! (make all things off and 0)
  my $isAlgorithmSubclass = $algorithmSubclassesHash->{$filterHash->{"Filter_Name"}};
  foreach my $input ( @{$filterHash->{"Inputs"}} ) {
  my $inputFlags = $input->{"Input_Flags"};
  my $inputName = $input->{"Input_Name"};
  if ($inputFlags eq "Optional"){
    $string .= "off|";
  }
  elsif ($inputFlags eq "Repeatable,Optional"){
    $string .= "0|";
  }
  }
  return $string;
}

##########################################################
# getMaskValueParameterString
# ex: "0|[0,0,0]|0|0"
##########################################################
sub getMaskValueParameterString{
  my $filterHash = shift;
  my $string = "";
  
  foreach my $param ( @{$filterHash->{"Filter_Parameters"}} ) {
  my $paramSize = $param->{"Parameter_Size"};
  #CHANGE HERE! (remove the off)
  $string .= "Use Default|"; # take care of indicators
  if ($paramSize > 1 && $paramSize != "N"){ # if is an array of known size
    $string .= getArrayOfZerosString($paramSize);
  }
  else {
    $string .= "0|";
  }
  }
  return $string;
}
##########################################################
# getArrayOfZerosString
# pass in the number of zeros that should be in array and get back a string
# ex: [0,0,0]|
##########################################################
sub getArrayOfZerosString{
  my $numberOfZeros = shift;
  my $string = "[";
  
  for (my $i = 0; $i < $numberOfZeros; $i++){
    $string .= "0,";
  }
  chop($string); #remove last character ","
  $string .= "]|"; #close array bracket and add "|" character
}

##########################################################
# getMaskValueOutputString
# ex: "on|on|on"
##########################################################
sub getMaskValueOutputString{
  my $filterHash = shift;
  my $algorithmSubclassesHash = shift;
  my $string = "";
  
  my $isAlgorithmSubclass = $algorithmSubclassesHash->{$filterHash->{"Filter_Name"}};
  foreach my $output ( @{$filterHash->{"Outputs"}} ) {
  my $outputName = $output->{"Output_Name"};
  #CHANGE HERE2! (make all off, except for if is called self and not part of algorithm class... so will need to bring algorithm subclasses hash into this module and then do the proper checks)
    if ($outputName eq "Self" && !$isAlgorithmSubclass){
      $string .= "on|";
    }
    else {
      $string .= "off|";
    }
  }
  return $string;
}

