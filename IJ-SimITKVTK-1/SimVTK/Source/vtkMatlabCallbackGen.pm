package vtkMatlabCallbackGen;


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
our @EXPORT = qw(vtkMatlabCallbackGen);

##########################################################
# FilterMaskGen subroutine
# Generates the code for a m file callback that corresponds to one filter. 
#
# Input: 1. reference to %filterHash
# 	2. Directory to store finished Callback m file
# Returns: M file code for the current filter's callback function
##########################################################
sub vtkMatlabCallbackGen {

  my ($filterHash, $directory, $algorithmSubclassesHash, $sourceDirectory) = @_;
  
  #find out whether the filter contains parameters or not
 die "ERROR: vtkMatlabCallback.m.in file not found"
  unless -f $sourceDirectory . "/vtkMatlabCallback.m.in";
  open (INFILE, "<", $sourceDirectory . "/vtkMatlabCallback.m.in");

  
  undef $/;
  my $content = <INFILE>;
  
  $/ = "\n";
  close INFILE;
  
  # if is not on Windows, remove the control-M characters
  if ($^O ne "MSWin32") {
    $content =~ s/\cM//g;
  }
  
  # Create the output file
  open (OUTFILE, ">$directory/Sim" . $filterHash->{"Filter_Name"} . "Callback.m");
  
  
  # FILTER_NAME 
  my $filterName = $filterHash->{"Filter_Name"};
  $content =~ s/\@FILTER_NAME\@/$filterName/g;

  
  #CALLBACK_FUNCTIONS_STRING     
  my $callbackString = getCallbackString($filterHash);
  $content =~ s/\@FUNCTION_CALLBACK_STRING\@/$callbackString/g;
   
  #PORT_LABEL_STRING     
  my $portLabelString = getPortLabelString($filterHash, $algorithmSubclassesHash);
  $content =~ s/\@PORT_LABEL_STRING\@/$portLabelString/g;
  
  print OUTFILE $content;
  close OUTFILE;
}

##########################################################
# getCallbackString
# gets the string for the callback functions in matlab. 
##########################################################
sub getCallbackString{
  my $filterHash = shift;
  my $string = "";
  my $count = 1;
  
  $string = $string . getInputString($filterHash, \$count);
  $string = $string . getParameterString($filterHash, \$count);
  $string = $string . getOutputString($filterHash, \$count);
  
  return $string;
}

##########################################################
#getInputString
#gets the input names of a filter for the callback codes
##########################################################
sub getInputString{
  my $filterHash= shift;
    my $count = shift;
  my $string = "";
  
  foreach my $input (@{$filterHash->{"Inputs"}} ){
    my $inputName = $input->{"Input_Name"};
    $string = $string . "function VTKInput" . $inputName . "Callback(block)\n" .
        "  val = get_param(block,'MaskValues');\n" .
      "  set_param(block, 'MaskValues', val); %%to update the blocks number of ports\n" .
      "  SetPortLabels(block)\n\n";
        $$count++;
  }
  return $string;
}

##########################################################
#getParamterString
#gets the parameter callback string of a filter for matlab callback
##########################################################
sub getParameterString{
  my $filterHash= shift;
    my $count = shift;
  my $string ="";
  
  #CHANGE HERE! ( remove outputIndicator part)
  foreach my $param (@{$filterHash->{"Filter_Parameters"}} ){
    my $paramName = $param->{"Parameter_Name"};
    $string = $string . "function " . $paramName . "InputIndicatorCallback(block)\n\n" .
        "  vals = get_param(block,'MaskValues');\n" .
        "  vis = get_param(block,'MaskVisibilities');\n" .
        "  if strcmp(vals{" . $$count . "},'As Parameter'),\n" .
    "    set_param(gcb,'MaskVisibilities',[vis(1:" . ($$count) . ");{'on'};vis(" . ($$count + 2) . ":end)]),\n" .
        "  else\n" .		
        "    set_param(gcb,'MaskVisibilities',[vis(1:" . ($$count) . ");{'off'};vis(" . ($$count + 2) . ":end)]),\n" .
        "  end\n" .
    "  set_param(block, 'MaskValues', vals); %%to update the blocks number of ports\n" .
    "  SetPortLabels(block)\n\n".
        "function VTKParam" . $paramName . "Callback(block)\n\n" ;
        $$count = $$count +2;
  }
    
    return $string;
}

##########################################################
#getOutputString
#gets the output callback string of a filter for the matlab callback
##########################################################
sub getOutputString{
  my $filterHash= shift;
    my $count = shift;
  my $string = "";
  
  foreach my $output (@{$filterHash->{"Outputs"}} ){
    my $outputName = $output->{"Output_Name"};
    $string = $string . "function VTKOutput" . $outputName . "Callback(block)\n" .
        "  val = get_param(block,'MaskValues');\n" .
      "  set_param(block, 'MaskValues', val); %%to update the blocks number of ports\n" .
      "  SetPortLabels(block)\n\n";
        $$count ++;
  }
  return $string;
}

##########################################################
#getPortLabelString
# gets the port labels for the matlab callback
# has vtkAlgorithmOutput first followed by all other normal inputs and outputs
##########################################################
sub getPortLabelString{
  my $filterHash = shift;
  my $algorithmSubclassesHash = shift;
  my $string = "";
  my $count = 1;
  
  $string .= "function SetPortLabels(block)\n\nval = get_param(block,'MaskValues');\nportString = {};\nincount = 1;\noutcount = 1;\n" .
  "ports = get_param(block, 'Ports');\n" ;
  
  if ($algorithmSubclassesHash->{$filterHash->{"Filter_Name"}})
  {
  $string = $string . getPortLabelAlgorithmOutputString($filterHash, \$count);
  }
  $string = $string . getPortLabelInputString($filterHash, \$count);
  $string = $string . getPortLabelParameterString($filterHash, \$count);
  $string = $string . getPortLabelOutputString($filterHash, \$count);
  
  $string .= "numPorts = get_param(block, 'Ports');\n";
  $string .= "set_param(gcs, 'Lock', 'off');\n";
  $string .= "set_param(block,'MaskDisplay',char(portString));\n";
  
  return $string;
}

##########################################################
#getPortLabelAlgorithmOutputString
# gets the port labels for the matlab callback for all the vtkObject needed input/outputs
# currently seems a little overly inefficient and complicated to have input names while keeping 
#vtkAlgorithmOutputs at the top... must think of way to improve...
##########################################################
sub getPortLabelAlgorithmOutputString{
  my $filterHash = shift;
  my $count = shift;
  
  my $string = "";
  my $numInputs = scalar @{$filterHash->{"Inputs"}};
  my $numParams = 2 * scalar @{$filterHash->{"Filter_Parameters"}};
  my $numOutputs = scalar @{$filterHash->{"Outputs"}};
  
  $string = $string . "totalInCount = 0;\n" .
  "totalOutCount = 0;\n" .
  #Inputs
  "for i = 1:1:" . $numInputs . "\n" .
  "  if strcmp(val{i}, 'on')\n" .
  "    totalInCount = totalInCount +1;\n" .
  "  elseif strcmp(val{i}, 'off') %%ignore\n" .
  "  else\n" .
  "    totalInCount = totalInCount + str2num(val{i});\n" .
  "  end\n" .
  "end\n" .
  #Parameters
  "for i = " . ($numInputs + 1) . ":2:" . ($numInputs + $numParams) . "\n" .
  "  if strcmp(val{i},'As Input')\n" .
  "    totalInCount = totalInCount + 1;\n" .
  "  end\n" .
  "end\n" .
  "for i = " . ($numInputs + 1) . ":2:" . ($numInputs + $numParams) . "\n" .
  "  if strcmp(val{i},'As Output')\n" .
  "    totalOutCount = totalOutCount + 1;\n" .
  "  end\n" .
  "end\n" .
  #Outputs
  "for i = " . ($numInputs + $numParams +1) . ":1:" . ($numInputs + $numParams + $numOutputs) . "\n" .
  "  if strcmp(val{i},'on')\n" .
  "    totalOutCount = totalOutCount + 1;\n" .
  "  end\n" .
  "end\n" .
  # Now actually label the beginning output port labels with the right stuff
  "for i = totalInCount+1:1:ports(1)\n" .
  "  portString = [portString;{['port_label(''input'',', num2str(incount), ',''Input'')']}];\n" .
  "  incount = incount + 1; \n" .
  "end\n" .
  "for i = totalOutCount+1:1:ports(2)\n" .
  "  portString = [portString;{['port_label(''output'',', num2str(outcount), ',''Output'')']}];\n" .
  "  outcount = outcount + 1; \n" .
  "end\n" ;
    
  return $string;
}

##########################################################
#getPortLabelInputString
# gets the port labels for normal input types in block 
##########################################################
sub getPortLabelInputString{
  my $filterHash = shift;
  my $count = shift;
  
  my $string= "";
  
    foreach my $input (@{$filterHash->{"Inputs"}} )
  {
    my $inputName = $input->{"Input_Name"};
    my $inputFlags = $input->{"Input_Flags"};
    
    if ($inputFlags eq "Optional")
    {
          $string = $string . "if strcmp(val{" . $$count . "}, 'on')\n" .
          "  portString = [portString;{['port_label(''input'',', num2str(incount), ',''" . $inputName . "'')']}];\n" .
      "  incount = incount + 1; \n" .
          "end\n" ;
    }
    elsif ($inputFlags eq "Repeatable,Optional")
    {
      $string = $string . "for i = 1:1:str2num(val{" . $$count . "})\n" .
      "  portString = [portString;{['port_label(''input'',',num2str(incount),',''" . $inputName . "'')']}];\n" .
      "  incount = incount +1;\n" .
      "end\n";
    }
    $$count++;
    }
  return $string;
}

##########################################################
#getPortLabelParamterString
# gets the port labels for normal paratmeter types in block 
##########################################################
sub getPortLabelParameterString{
  my $filterHash = shift;
  my $count = shift;
  
  my $string = "";
    foreach my $parameter (@{$filterHash->{"Filter_Parameters"}} ){
    my $parameterName = $parameter->{"Parameter_Name"};
    $string .= getPortLabelInputParameterString($parameterName, $count);
    $string .= getPortLabelOutputParameterString($parameterName, $count);
        $$count = $$count + 2;
    }
    
  return $string;
}

##########################################################
#getPortLabelInputParamterString
# gets the port labels for normal parameters promoted to input types in block 
##########################################################
sub getPortLabelInputParameterString{
  my $parameterName = shift;
  my $count = shift;

  my $string = "";
  
  $string = $string . "if strcmp(val{" . $$count . "}, 'As Input')\n" .
  "  portString = [portString;{['port_label(''input'',', num2str(incount), ',''" . $parameterName . "'')']}];\n" .
  "  incount = incount + 1; \n" .
  "end\n" ;
  return $string;
}

##########################################################
#getPortLabelOutputParameterString
# gets the port labels for normal parameter promoted to output types in block 
##########################################################
sub getPortLabelOutputParameterString{
  my $parameterName = shift;
  my $count = shift;
  
 my $string = "";
  
  #CHANGE HERE! (make it so it's more like the one above)
  $string = $string . "if strcmp(val{" . $$count . "}, 'As Output')\n" .
  "  portString = [portString;{['port_label(''output'',', num2str(outcount), ',''" . $parameterName . "'')']}];\n" .
  "  outcount = outcount + 1; \n" .
  "end\n" ;
  return $string;
}


##########################################################
#getPortLabelOutputString
# gets the port labels for normal output types in block 
##########################################################
sub getPortLabelOutputString{
  my $filterHash = shift;
  my $count = shift;
  
  my $string = "";
  
  my $filterName = $filterHash->{"Filter_Name"};
    foreach my $output (@{$filterHash->{"Outputs"}} ){
    my $outputName = $output->{"Output_Name"};
        $string = $string . "if strcmp(val{" . $$count . "}, 'on')\n" .
        "  portString = [portString;{['port_label(''output'',', num2str(outcount), ',''";
    if ($outputName eq "Self"){
      $string = $string . "Self";
    }
    else {
      $string = $string . $outputName;
    }
    $string = $string . "'')']}];\n" .
    "  outcount = outcount + 1; \n" .
        "end\n";
        $$count++;
    }
  
  return $string;
}

