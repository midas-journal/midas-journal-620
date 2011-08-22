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

my $readerName = "Reader" . datatypeCode($inputPixeltype) . $dimensionality;
#---------------Create Readerxxx.tpp---------------#
#Read the input file into a single string
open (INFILE, "<Reader.tpp.in");
undef $/;
my $content = <INFILE>;

$/ = "\n";
close INFILE;

#Create the output file
open (OUTFILE, ">$directory/" . $readerName . ".tpp");

# READER_NAME
$content =~ s/\@READER_NAME\@/$readerName/g;

print OUTFILE $content;
close OUTFILE;

#---------------Create ReaderxxxMat.cpp---------------#
#Read the input file into a single string
open (INFILE, "<ReaderMat.cpp.in");
undef $/;
my $content = <INFILE>;

$/ = "\n";
close INFILE;

#Create the output file
open (OUTFILE, ">$directory/" . $readerName . "Mat.cpp");

# READER_NAME
$content =~ s/\@READER_NAME\@/$readerName/g;
#DIMENSIONALITY
$content =~ s/\@DIMENSIONALITY\@/$dimensionality/g;
#PIXELTYPE
$content =~ s/\@PIXELTYPE\@/$inputPixeltype/g;
#SIMULINK_PIXELTYPE
my $simulinkPixeltype = simulinkDatatype($inputPixeltype);
$content =~ s/\@SIMULINK_PIXELTYPE\@/$simulinkPixeltype/g;
#SIMULINK_PIXELTYPE_INDEX
my $simulinkPixeltypeIndex = simulinkDatatypeIndex($inputPixeltype);
$content =~ s/\@SIMULINK_PIXELTYPE_INDEX\@/$simulinkPixeltypeIndex/g;

print OUTFILE $content;
close OUTFILE;

my $writerName = "Writer" . datatypeCode($outputPixeltype) . $dimensionality;
#---------------Create Writerxxx.tpp---------------#
#Read the input file into a single string
open (INFILE, "<Writer.tpp.in");
undef $/;
my $content = <INFILE>;

$/ = "\n";
close INFILE;

#Create the output file
open (OUTFILE, ">$directory/" . $writerName . ".tpp");

# WRITER_NAME
$content =~ s/\@WRITER_NAME\@/$writerName/g;

print OUTFILE $content;
close OUTFILE;

#---------------Create WriterxxxMat.cpp---------------#
#Read the input file into a single string
open (INFILE, "<WriterMat.cpp.in");
undef $/;
my $content = <INFILE>;

$/ = "\n";
close INFILE;

#Create the output file
open (OUTFILE, ">$directory/" . $writerName . "Mat.cpp");

# WRITER_NAME
$content =~ s/\@WRITER_NAME\@/$writerName/g;
#DIMENSIONALITY
$content =~ s/\@DIMENSIONALITY\@/$dimensionality/g;
#PIXELTYPE
$content =~ s/\@PIXELTYPE\@/$outputPixeltype/g;
#SIMULINK_PIXELTYPE
my $simulinkPixeltype = simulinkDatatype($outputPixeltype);
$content =~ s/\@SIMULINK_PIXELTYPE\@/$simulinkPixeltype/g;
#SIMULINK_PIXELTYPE_INDEX
my $simulinkPixeltypeIndex = simulinkDatatypeIndex($outputPixeltype);
$content =~ s/\@SIMULINK_PIXELTYPE_INDEX\@/$simulinkPixeltypeIndex/g;

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

