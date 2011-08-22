package BaseClassCopy;

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
use File::Copy;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(BaseClassCopy);

##########################################################
# FilterMaskGen subroutine
#  Copies base class files from the source directory to the bin directory. 
#
# Input: 1. bin directory where generated source code should be placed
##########################################################

sub BaseClassCopy{

    my $directory = shift;

    #---------------Copy VirtualPort.h---------------#
    my $virtualPortHeaderFile = "VirtualPort.h";
    my $newVirtualPortHeaderFile = "$directory/VirtualPort.h";
    copy($virtualPortHeaderFile, $newVirtualPortHeaderFile) 
        or die "Error: The file $virtualPortHeaderFile cannot be copied.\n";
    
    #---------------Copy VirtualSpecialPort.h---------------#
    my $virtualSpecialPortHeaderFile = "VirtualSpecialPort.h";
    my $newVirtualSpecialPortHeaderFile = "$directory/VirtualSpecialPort.h";
    copy($virtualSpecialPortHeaderFile, $newVirtualSpecialPortHeaderFile) 
        or die "Error: The file $virtualSpecialPortHeaderFile cannot be copied.\n";

    #---------------Copy VirtualBlock.h---------------#
    my $virtualBlockHeaderFile = "VirtualBlock.h";
    my $newVirtualBlockHeaderFile = "$directory/VirtualBlock.h";
    copy($virtualBlockHeaderFile, $newVirtualBlockHeaderFile) 
        or die "Error: The file $virtualBlockHeaderFile cannot be copied.\n";
    
    #---------------Copy ImageConversion.h---------------#
    my $imageConversionHeaderFile = "ImageConversion.h";
    my $newImageConversionHeaderFile = "$directory/ImageConversion.h";
    copy($imageConversionHeaderFile, $newImageConversionHeaderFile) 
        or die "Error: The file $imageConversionHeaderFile cannot be copied.\n";
    
    #---------------Copy ImageConversion.tpp---------------#
    my $imageConversionTPPFile = "ImageConversion.tpp";
    my $newImageConversionTPPFile = "$directory/ImageConversion.tpp";
    copy($imageConversionTPPFile, $newImageConversionTPPFile) 
        or die "Error: The file $imageConversionTPPFile cannot be copied.\n";
}

