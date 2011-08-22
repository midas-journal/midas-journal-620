package FilterMaskGen;

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
# FilterMaskGen.pm
###############################################

use strict;
use Switch;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(FilterMaskGen);

##########################################################
# FilterMaskGen subroutine
# Generates the code for a S-function mask that corresponds to one filter. 
#
# Input: 1. reference to %filterHash
#        2. string containing the code for previous filters
#        3. dimensionality of the filter
#        4. input pixel type of the filter
# Returns: Mask code for the current filter accumulated with the code from previous filters
##########################################################
sub FilterMaskGen {

  my ($filterHash, $position) = @_;
  
  #find out whether the filter contains parameters or not
  my $numFilterParameters = scalar @{$filterHash->{"Parameters"}};
  
  if ($numFilterParameters > 0){
    open (INFILE, "<FilterMask.in");
  }else{
    open (INFILE, "<FilterMaskNoParameters.in");
  }
  
  undef $/;
  my $content = <INFILE>;
  
  $/ = "\n";
  close INFILE;
  
  # FILTER_NAME
  my $filterName = $filterHash->{"Name"};
  $content =~ s/\@FILTER_NAME\@/$filterName/g;
 
  # NUM_INPUT_PORTS
  my $numInputs = (defined $filterHash->{"Inputs"}) ? scalar @{$filterHash->{"Inputs"}} : 0;
  my $numSpecialInputs = (defined $filterHash->{"Special_Inputs"}) ? scalar @{$filterHash->{"Special_Inputs"}} : 0;
  my $numInputPorts = $numInputs*2 + $numSpecialInputs;
  $content =~ s/\@NUM_INPUT_PORTS\@/$numInputPorts/g;
  
  # NUM_OUTPUT_PORTS
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $numSpecialOutputs = (defined $filterHash->{"Special_Outputs"}) ? scalar @{$filterHash->{"Special_Outputs"}} : 0;
  my $numOutputPorts = $numOutputs*2 + $numSpecialOutputs; 
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
  
  #BACKGROUND_COLOR
  my $backgroundColorString = getBackgroundColorString($filterHash);
  $content =~ s/\@BACKGROUND_COLOR\@/$backgroundColorString/g;
  
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
  my $maskValueString = getMaskValueString($filterHash);
  $content =~ s/\@MASK_VALUE_STRING\@/$maskValueString/g;
  
  #MASK_TAB_NAME_STRING
  $content =~ s/\@MASK_TAB_NAME_STRING\@/$maskCommaString/g;

  return $content;
}

##########################################################
# getBackgroundColorString
# ex: "[0.5, 0.5, 0.5]"
##########################################################
sub getBackgroundColorString {
  my $filterHash = shift;
  my $string = "\"";
  
  if ($filterHash->{"Object_Type"} eq "Filter") {
    $string = $string . "[1, 1, 1]\"";
  }
  elsif ($filterHash->{"Object_Type"} eq "Transform") {
    $string = $string . "[1, 1, 0.6]\"";
  }
  elsif ($filterHash->{"Object_Type"} eq "Interpolator") {
    $string = $string . "[1, 0.89, 0.77]\"";
  }
  return $string;
}

##########################################################
# getFilterParametersString
# gets the parameters of a filter and creates a string for the mask code. 
# ex: "MaximumError,MaximumKernelWidth,Variance"
##########################################################
sub getFilterParametersString{
  my $filterHash = shift;
  my $string = "\"";
  
  foreach my $param ( @{$filterHash->{"Parameters"}} ) {
    my $paramName = $param->{"Parameter_Name"};
    # Simulink does not allow 'Parameters' as a mask variable name
    if ($paramName eq "Parameters") {
      $paramName = "Parameters_a";
    }
    $string = $string . $paramName . ",";
  }
  chop($string); #removes the last character ","
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskPromptString
# gets the parameters of a filter and creates a string for the mask prompt. 
# ex: "MaximumError|MaximumKernelWidth|Variance"
##########################################################
sub getMaskPromptString{
  my $filterHash = shift;
  my $string = "\"";
  
  foreach my $param ( @{$filterHash->{"Parameters"}} ) {
    my $paramName = $param->{"Parameter_Name"};
    $string = $string . $paramName . "|";
  }
  chop($string); #removes the last character "|"
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskPromptString
# ex: "edit|edit|edit"
##########################################################
sub getMaskStyleString{
  my $filterHash = shift;
  my $string = "\"";
  
  my $numParameters = scalar @{$filterHash->{"Parameters"}};
  
  for (my $i = 0; $i < $numParameters; $i++){
    $string = $string . "edit,";
  }
  chop($string); #removes the last character ","
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskOnString
# ex: "On|On|On"
# note: This string is reused for more than one field in the filter mask code. 
##########################################################
sub getMaskOnString{
  my $filterHash = shift;
  my $string = "\"";
  
  my $numParameters = scalar @{$filterHash->{"Parameters"}};
  
  for (my $i = 0; $i < $numParameters; $i++){
    $string = $string . "on,";
  }
  chop($string); #removes the last character ","
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskCallbackString
# ex: "||"
##########################################################
sub getMaskCallbackString{
  my $filterHash = shift;
  my $string = "\"";
  
  my $numParameters = scalar @{$filterHash->{"Parameters"}};
  
  for (my $i = 0; $i < $numParameters; $i++){
    $string = $string . "|";
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
  
  my $numParameters = scalar @{$filterHash->{"Parameters"}};
  
  for (my $i = 0; $i < $numParameters; $i++){
    $string = $string . ",";
  }
  chop($string); #removes the last character ","
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskVariables
# ex: "MaximumError=@1;MaximumKernelWidth=@2;Variance=@3;"
##########################################################
sub getMaskVariables{
  my $filterHash = shift;
  my $string = "\"";
  my $count = 1;
  
  foreach my $param ( @{$filterHash->{"Parameters"}} ) {
    my $paramName = $param->{"Parameter_Name"};
    # Simulink does not allow 'Parameters' as a mask variable name
    if ($paramName eq "Parameters") {
      $paramName = "Parameters_a";
    }
    $string = $string . $paramName . "=@" . $count . ";";
    $count++;
  }
  $string = $string . "\"";
  return $string;
}

##########################################################
# getMaskDisplay
# ex:  "port_label('input',1,'info');\nport_label('input',2,'data');"
# "port_label('output',1,'info');\nport_label('output',2,'data');"
##########################################################
sub getMaskDisplay{
  my $filterHash = shift;
  my $string = "";
  my $numInputs = (defined $filterHash->{"Inputs"}) ? scalar @{$filterHash->{"Inputs"}} : 0;
  my $numSpecialInputs = (defined $filterHash->{"Special_Inputs"}) ? scalar @{$filterHash->{"Special_Inputs"}} : 0;
  my $numOutputs = (defined $filterHash->{"Outputs"}) ? scalar @{$filterHash->{"Outputs"}} : 0;
  my $numSpecialOutputs = (defined $filterHash->{"Special_Outputs"}) ? scalar @{$filterHash->{"Special_Outputs"}} : 0;
  my $portNum = 1;
  
  for (my $i = 1; $i <= $numInputs; $i++){
    $string = $string . "\"";

    $string = $string . "port_label('input',". $portNum . ",'info');"
      . "\\nport_label('input'," . ($portNum + 1) .",'data');\\n\"\n";
    $portNum = $portNum + 2;
  }
  for (my $i = 1; $i <= $numSpecialInputs; $i++){
    $string = $string . "\"";
    $string = $string . "port_label('input',". $portNum . ",'special');\\n\"\n";
    $portNum++;
  }
  
  $portNum = 1;
  for (my $i = 1; $i <= $numOutputs; $i++){
    $string = $string . "\"";
    $string = $string . "port_label('output',". $portNum . ",'info');"
      . "\\nport_label('output'," . ($portNum + 1) .",'data');\\n\"\n";
    $portNum = $portNum + 2;
  }
  for (my $i = 1; $i <= $numSpecialOutputs; $i++){
    $string = $string . "\"";
    $string = $string . "port_label('output',". $portNum . ",'self');\\n\"\n";
    $portNum++;
  }
  return $string;
}

##########################################################
# getMaskValueString
# ex: "0|0|0"
##########################################################
sub getMaskValueString{
  my $filterHash = shift;
  my $string = "\"";
  
  foreach my $param ( @{$filterHash->{"Parameters"}} ) {
    $string = $string . "0|";
  }
  chop($string); #removes the last character "|"
  $string = $string . "\"";
  return $string;
}

