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
###############################################

use strict;
use Switch;

# Input: 1. dimensionality
#            2. inputPixeltype
#            3. outputPixeltype
#            4. bin directory where generated source code should be placed
my $dimensionality = shift;
my $inputPixeltype = shift;
my $outputPixeltype = shift;
my $directory = shift;

my $containerName = "Container" . datatypeCode($inputPixeltype) . $dimensionality;
#---------------Create SimITKContainerxxx.tpp---------------#
#Read the input file into a single string
open (INFILE, "<Container.tpp.in");
undef $/;
my $content = <INFILE>;

$/ = "\n";
close INFILE;

#Create the output file
open (OUTFILE, ">$directory/" . "SimITK" . $containerName . ".tpp");

# READER_NAME
$content =~ s/\@CONTAINER_NAME\@/$containerName/g;

print OUTFILE $content;
close OUTFILE;

#---------------Create SimITKContainerxxxMat.cpp---------------#
#Read the input file into a single string
open (INFILE, "<ContainerMat.cpp.in");
undef $/;
my $content = <INFILE>;

$/ = "\n";
close INFILE;

#Create the output file
open (OUTFILE, ">$directory/" . "SimITK" . $containerName . "Mat.cpp");

# READER_NAME
$content =~ s/\@CONTAINER_NAME\@/$containerName/g;
#DIMENSIONALITY
$content =~ s/\@DIMENSIONALITY\@/$dimensionality/g;
#INPUT_PIXELTYPE
$content =~ s/\@INPUT_PIXELTYPE\@/$inputPixeltype/g;
#OUTPUT_PIXELTYPE
$content =~ s/\@OUTPUT_PIXELTYPE\@/$outputPixeltype/g;

print OUTFILE $content;
close OUTFILE;

##########################################################
# datatypeCode
# Converts a datatype string into a two-letter code.
#
# Input: datatype string
# Returns: two-letter datatype code
#                empty string if the input datatype is unrecognized
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

