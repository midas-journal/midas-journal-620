package LibraryGen;

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
# LibraryGen.pm
#
# Input: 1. dimensionality of the filter
#        2. input pixel type of the filter
#        3. data type ID code for the filter
#        4. MDL descriptions of all filters in the library
#        5. BIN directory where the library file should be placed
###############################################

use strict;
use Switch;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(LibraryGen);

sub LibraryGen {

  my ($dimensionality, $inputPixeltype, $datatypeID, $maskContent, $directory, $templateFile) = @_;

  # Read the input file into a single string
  open (INFILE, "<" . $templateFile);
  undef $/;
  my $content = <INFILE>;
  
  $/ = "\n";
  close INFILE;
  
  # Create the output file
  if ($templateFile eq "TransformLibrary.mdl.in") {
    # For now, append to any existing SimITKTransformLibrary.mdl so that transforms of all dimensionalities appear in the same library
    open (OUTFILE, ">$directory/SimITKTransformLibrary" . $dimensionality . "D.mdl");
  }
  else {
    open (OUTFILE, ">$directory/SimITKLibrary" . $datatypeID . ".mdl");
  }
  
  # DATA_TYPE_CODE
  $content =~ s/\@DATA_TYPE_ID\@/$datatypeID/g;
  
  #TIMESTAMP
  my $timestamp = gmtime();
  $content =~ s/\@TIMESTAMP\@/$timestamp/g;
  
  #FILTER_MASK_CODE
  $content =~ s/\@FILTER_MASK_CODE\@/$maskContent/g;
 
  print OUTFILE $content;
  close OUTFILE;
}

