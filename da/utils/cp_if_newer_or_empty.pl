#!/usr/bin/perl -w
# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 
#    Filipe Guimarães (Forschungszentrum Juelich GmbH) 
#
# This script compares the modification time of $filename and $cmpfilename
# and copies the first to $destfilename when it is newer, or it copies
# $emptyfile when it is older

use strict;
use Time::HiRes qw ( time );
use FindBin;
use lib "$FindBin::RealBin/../lib";
use LML_da_util qw( check_folder );

my $filename = $ARGV[0];      # File to be copied (when newer)
my $destfilename  = $ARGV[1]; # Final location of the file (or empty)
my $cmpfilename = $ARGV[2];   # Comparison file
my $emptyfile = $ARGV[3];     # Empty file to be copied when $filename is older

# Getting modification timestamp of $filename
my $filename_ts=0;
$filename_ts=(stat($filename))[9] if(-f $filename);

# Getting modification timestamp of $cmpfilename
my $cmpfilename_ts=0;
$cmpfilename_ts=(stat($cmpfilename))[9] if(-f $cmpfilename);

# Checkign if final folder exists
&check_folder($destfilename);
if( $filename_ts > $cmpfilename_ts) { 
  # If $filename is newer than $cmpfilename, copy it to $destfilename
  print "cp $filename $destfilename ...\n";
  system("cp $filename $destfilename");
} else { 
  # if $filename is older than $cmpfilename, copy empty xml to $destfilename
  print "cp $emptyfile $destfilename ...\n";
  system("cp $emptyfile $destfilename");
}
