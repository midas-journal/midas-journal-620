package vtkLibraryGen;


# =================
# Copyright (c) Queen's University
# All rights reserved.

# See Copyright.txt for more details.
# =================

###############################################
# SIMITK Project
# Karen Li and Jing Xiang
# May 23, 2008
#
# LibraryGen.pm
#
###############################################

use strict;
use Fcntl ':flock';


require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(vtkLibraryGen);

sub vtkLibraryGen {

  my ($maskContent, $directory, $libraryName, $sourceDirectory) = @_;

  die "ERROR: vtkLibrary.mdl.in file not found"
  unless -f $sourceDirectory . "/vtkLibrary.mdl.in";
  
  # Read the input file into a single string
  
  my $check = open (INFILE, "<", "$directory/Simvtk" . $libraryName . "LibraryTemp.mdl");
  flock(INFILE, 2);
  # If the specific library has not yet been created open the default template library
  if ($check == undef){
    flock(INFILE, 8);
    close INFILE;
    if ($libraryName eq "Imaging"){
      open (INFILE, "<",  $sourceDirectory . "/vtkImagingLibrary.mdl.in");
      flock(INFILE,2);
    }
    else {
      open (INFILE, "<", $sourceDirectory . "/vtkLibrary.mdl.in");
      flock(INFILE, 2);
    }
  }
  undef $/;
  my $content = <INFILE>;
  
  $/ = "\n";
  flock (INFILE, 8);
  close INFILE;
  
  # if is not on Windows, remove the control-M (return) characters
  if ($^O ne "MSWin32") {
    $content =~ s/\cM//g;
  }
  

  #LIBRARY_HEADER
  $content =~ s/\@LIBRARY_HEADER\@/$libraryName/g;
  
  #TIMESTAMP
  my $timestamp = gmtime();
  $content =~ s/\@TIMESTAMP\@/$timestamp/g;
  
  #FILTER_MASK_CODE
  #Since there is no way to comment in .mdl files, and will be adding more mask content to the (almost) end of the file many times,
  # and cannot know when will be last time, added a -FINALIZE step to remove the @FILTER_MASK_CODE@ line
  #$content =~ s/.+\}\s+\}/$maskContent\n  \}\n\}/sg;  #alternate less pretty way
  
  # Create the output file
  if ($maskContent eq "") {
    open(OUTFILE, ">$directory/Simvtk" . $libraryName . "Library.mdl");
    flock(OUTFILE, 2);
    $content =~ s/\@FILTER_MASK_CODE\@/$maskContent/g;
  }
  else {
    open(OUTFILE, ">$directory/Simvtk" . $libraryName . "LibraryTemp.mdl");
    flock(OUTFILE, 2);
    $content =~ s/\@FILTER_MASK_CODE\@/\@FILTER_MASK_CODE\@$maskContent/g;
  }

  print OUTFILE $content;
  flock(OUTFILE, 8);
  close OUTFILE;
  
}
