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
use Data::Dumper;

use Time::HiRes qw ( time alarm sleep );

use FindBin;
use lib "$FindBin::RealBin/.";
use lib "$FindBin::RealBin/../lib";

use LLmonDB;

my $patint="([\\+\\-\\d]+)";   # Pattern for Integer number
my $patfp ="([\\+\\-\\d.E]+)"; # Pattern for Floating Point number
my $patwrd="([\^\\s]+)";       # Pattern for Work (all noblank characters)
my $patbl ="\\s+";             # Pattern for blank space (variable length)

#####################################################################
# get user info / check system 
#####################################################################
my $UserID = getpwuid($<);
my $Hostname = `hostname`;
my ($filename);

my $opt_verbose=0;
my $opt_dryrun=1;
my $opt_force=0;
my $opt_config=undef;
my $opt_dbdir=undef;
my $opt_pdepth=undef;
my $opt_outfile="stdout";

# Examples:
# time ~/llview/da/LLmonDB/LLmonDB_mnt.pl -config=test.yaml checkDB

usage($0) if( ! GetOptions( 
                'verbose'          => \$opt_verbose,
                'force'            => \$opt_force,
                'dbdir=s'          => \$opt_dbdir,
                'config=s'         => \$opt_config,
                'outfile=s'        => \$opt_outfile,
                'pdepth=s'         => \$opt_pdepth
                ) );

my $operation=$ARGV[0];

if(!$operation) {
  print "please specify an operation, leaving...\n";
  usage($0);
  exit;
}

if(!$opt_config) {
  print "please specify config-file (-config=<file>.yaml), leaving...\n";
  usage($0);
  exit;
}

if(! -f $opt_config) {
  print "config-file $opt_config does not exist, leaving...\n";
  usage($0);
  exit;
}

my ($starttime);

if($opt_force) {
  $opt_dryrun=0;
}

if($operation=~/checkDB/i) {
  printf("OPERATION:    checkDB\n");
  printf("     config:  $opt_config\n");
  printf("     verbose: $opt_verbose\n");
  printf("     force:   $opt_force [dryrun=$opt_dryrun]\n");

  my $DB;
  $starttime=time();
  $DB  = LLmonDB->new($opt_config,$opt_dbdir,undef,$opt_verbose);
  printf("    [open DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->init();
  printf("    [init DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->checkDB($opt_dryrun);
  printf("    [check DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->close();
  printf("    [close DB file in %7.5ss]\n",time()-$starttime);

} elsif($operation=~/printconfig/i) {
  printf("OPERATION:    printconfig\n");
  printf("     config:  $opt_config\n");
  printf("     verbose: $opt_verbose\n");
  printf("     outfile: $opt_outfile\n");

  my $DB;
  $starttime=time();
  $DB  = LLmonDB->new($opt_config,$opt_dbdir,undef,$opt_verbose);
  printf("    [create DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->init();
  printf("    [init DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  my $config=$DB->get_confighandle();
  $config->print_to($opt_outfile);
  printf("    [init DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->close();
  printf("    [close DB file in %7.5ss]\n",time()-$starttime);

} elsif($operation=~/dumpconfig/i) {
  printf("OPERATION:    dumpconfig\n");
  printf("     config:  $opt_config\n");
  printf("     deep:    $opt_pdepth\n");
  printf("     verbose: $opt_verbose\n");
  printf("     outfile: $opt_outfile\n");

  my $DB;
  $starttime=time();
  $DB  = LLmonDB->new($opt_config,$opt_dbdir,undef,$opt_verbose);
  printf("    [create DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->init();
  printf("    [init DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  my $config=$DB->get_confighandle();
  $config->dump_to($opt_outfile,$opt_pdepth);
  printf("    [init DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->close();
  printf("    [close DB file in %7.5ss]\n",time()-$starttime);

} elsif($operation=~/testconfig/i) {
  printf("OPERATION:    testconfig\n");
  printf("     config:  $opt_config\n");
  printf("     verbose: $opt_verbose\n");

  my $DB;
  $starttime=time();
  $DB  = LLmonDB->new($opt_config,$opt_dbdir,undef,$opt_verbose);
  printf("    [create DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->init();
  printf("    [init DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->close();
  printf("    [close DB file in %7.5ss]\n",time()-$starttime);
} elsif($operation=~/graphs/i) {
  printf("OPERATION:    graphs\n");
  printf("     config:  $opt_config\n");
  printf("     verbose: $opt_verbose\n");
  printf("     outfile: $opt_outfile\n");

  my $DB;
  $starttime=time();
  $DB  = LLmonDB->new($opt_config,$opt_dbdir,undef,$opt_verbose);
  printf("    [create DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->init();
  printf("    [init DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->print_graphsDB($opt_outfile);
  printf("    [graphs DB file in %7.5ss]\n",time()-$starttime);

  $starttime=time();
  $DB->close();
  printf("    [close DB file in %7.5ss]\n",time()-$starttime);
} else {
  usage($0);
}


sub mysystem {
  my($call)=@_;

  printf("  --> exec: %s\n",$call) if($opt_verbose>=1);
  system($call);
  my $rc = $?;
  if ($rc) {
    printf(STDERR "  ERROR --> exec: %s\n",$call);
    printf(STDERR "  ERROR --> rc=%d\n",$rc);
  } else {
    printf("           rc=%d\n",$rc) if($opt_verbose>=2);
  }
}

sub usage {
    die "Usage: $_[0] <options> <operation> 
                --config <conffile>       : LLmonDB config file in YAML format
                --dbdir <path_to_db>      : overwrites the data base path from conffile
                --outfile <outfile>       : file parameter used in printconfig and dumpconfig
                --pdepth <level>          : limit for depth when dumping configfile
                --force                   : force modifications to data base
                --verbose                 : verbose

        operations: 
                testconfig  : reads config file only
                printconfig : print on stdout or <outfile> contents of config file
                dumpconfig  : print on stdout or <outfile> contents of config file (as data structure)             
                checkDB     : - check consistency of DB definition, 
                              - reports differences to config file
                              - with option --force make changes to data base 
";
}
