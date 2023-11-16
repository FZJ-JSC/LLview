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
#use warnings::unused -global;
use Getopt::Long;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

use FindBin;
use lib "$FindBin::RealBin/";
use lib "$FindBin::RealBin/../lib";

use lib "$FindBin::RealBin/../LLmonDB";
use LLmonDB;

# use LML_da_util;

my $patint="([\\+\\-\\d]+)";   # Pattern for Integer number
my $patfp ="([\\+\\-\\d.E]+)"; # Pattern for Floating Point number
my $patwrd="([\^\\s]+)";       # Pattern for Work (all noblank characters)
my $patbl ="\\s+";             # Pattern for blank space (variable length)

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
my $opt_verbose=0;
my $opt_timings=0;
my $opt_dump=0;
my $opt_demo=0;
my $opt_only_system=0;
my $opt_maxproc=8;
my $opt_config=undef;
my $opt_dbdir=undef;
my $opt_archdir=undef;
my $opt_dblist=undef;
my $caller=$0;$caller=~s/^.*\/([^\/]+)$/$1/gs;
my $instname="[${caller}][PRIMARY]";

usage($0) if( ! GetOptions( 
              'verbose'          => \$opt_verbose,
              'timings'          => \$opt_timings,
              'config=s'         => \$opt_config,
              'dbdir=s'          => \$opt_dbdir,
              'archdir=s'        => \$opt_archdir,
              'dblist=s'         => \$opt_dblist,
              'maxprocesses=i'   => \$opt_maxproc,
              'dump'             => \$opt_dump,
              'demo'             => \$opt_demo
              ) );


if(! -f $opt_config) {
  print "config-file $opt_config does not exist ... leaving\n";
  usage($0);
  exit;
}

my $DB;

my $starttime=time();
$DB = LLmonDB->new($opt_config,$opt_dbdir,$opt_archdir,$opt_verbose);
$DB->init();
printf("%s open DB                                         in %7.4fs\n",$instname,time()-$starttime);


$starttime=time();
$DB->archive_data($opt_dblist,$opt_maxproc);  
printf("%s archiving LML data                              in %7.4fs\n",$instname,time()-$starttime);

$DB->close();  

sub usage {
    die "Usage: $_[0] <options> <filenames> 
                -config <file>           : YAML config file
                -verbose                 : verbose
                -maxprocesses            : max number of processes used (default: 8)
";
}
