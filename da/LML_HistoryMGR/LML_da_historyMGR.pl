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

use strict;
use Getopt::Long;
use Time::Local;
use Time::HiRes qw ( time );

use FindBin;
use lib "$FindBin::RealBin/";
use lib "$FindBin::RealBin/../lib";

use LML_da_historyMGR;

#####################################################################
# get user info / check system 
#####################################################################
my $UserID = getpwuid($<);
my $Hostname = `hostname`;
my $verbose=1;
my ($filename);

#####################################################################
# get command line parameter
#####################################################################

# option handling
my $opt_timings=0;
my $opt_dump=0;
my $opt_histdir="./hist";
my $opt_infile="./test.lml";
my $opt_format="llview"; # llview|LML
my $opt_verbose=0;
my $opt_onlydb=0;
my %config;

usage($0) if( ! GetOptions( 
                'verbose'          => \$opt_verbose,
                'timings'          => \$opt_timings,
                'dump'             => \$opt_dump,
                'format=s'         => \$opt_format,
                'infile=s'         => \$opt_infile,
                'onlydb'           => \$opt_onlydb,
                'histdir=s'        => \$opt_histdir,
                ) );

&usage($0) if(!$opt_infile);
&usage($0) if(!$opt_histdir);
&usage($0) if(!$opt_format);

if($opt_verbose) {
  printf("infile   = %s\n",$opt_infile);
  printf("histdir  = %s\n",$opt_histdir);
  printf("format   = %s\n",$opt_format);
}

my $historymgr=LML_da_historyMGR->new($opt_histdir,$opt_format,$opt_verbose,$opt_onlydb);
my $rc=$historymgr->store($opt_infile);
&die("Could not store XML file in history") if($rc!=0);


sub usage {
  die "Usage: $_[0] <options> <filenames> 
                -verbose                 : verbose
                -infile <file>           : output filename
                -histdir <dir>           : directory containing history files
                -format <format>         : input file format: LML or llview 
                -onlydb                  : don't store file in tar file create only .dat files
";
}
