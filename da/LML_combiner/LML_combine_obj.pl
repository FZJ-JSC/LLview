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
use Time::HiRes qw ( time );

use FindBin;
use lib "$FindBin::RealBin/";
use lib "$FindBin::RealBin/../lib";

use LML_combine_file_obj;
use LML_combine_obj_check;
use LML_combine_obj_gpfs;
use LML_combine_obj_cluster;

#####################################################################
# get user info / check system 
#####################################################################
my $UserID = getpwuid($<);
my $Hostname = `hostname`;
my $verbose=1;
my ($filename);

my $starttime=time();

#####################################################################
# get command line parameter
#####################################################################

# option handling
my $opt_outfile="./test.lml";
my $opt_verbose=0;
my $opt_timings=0;
my $opt_dump=0;
my $opt_pstat=0;
my $opt_update=1;
my $opt_jcheck=1;
my $opt_keep=0; # If keep is true, two objects with the same ID will be merged, otherwise a new object is created for each of both 
my $opt_dbdir="./";
my $opt_systemtype="unknown";
usage($0) if( ! GetOptions( 
      'verbose'          => \$opt_verbose,
      'timings'          => \$opt_timings,
      'dump'             => \$opt_dump,
      'dbdir=s'          => \$opt_dbdir,
      'output=s'         => \$opt_outfile,
      'systemtype=s'     => \$opt_systemtype,
      'update!'          => \$opt_update,
      'jcheck!'          => \$opt_jcheck,
      'pstat!'           => \$opt_pstat,
      'keep'             => \$opt_keep,
      ) );

#print "@ARGV ($opt_outfile)\n";
if ($#ARGV < 0) {
  &usage($0);
}
my @filenames = @ARGV;

my $system_sysprio=-1;
my $maxtopdogs=-1;
my $filehandler;

$filehandler=LML_combine_file_obj->new($opt_verbose,$opt_timings, $opt_keep);

foreach $filename (@filenames) {
  print "reading file: $filename  ...\n" if($opt_verbose); 
  $filehandler->read_lml_fast($filename) if(-f $filename);
}

# determine system type
my $system_type = "unknown";

my $system_type_ref;
if($opt_systemtype ne "unknown" ) {
  $system_type = $opt_systemtype;
} else {
  keys(%{$filehandler->{DATA}->{OBJECT}}); # reset iterator
  my($key,$ref);
  while(($key,$ref)=each(%{$filehandler->{DATA}->{OBJECT}})) {
    if(($ref->{type} eq 'system') && ($key=~/^sys/)) {
      $system_type_ref=$ref=$filehandler->{DATA}->{INFODATA}->{$key};
      if($ref->{type}) {
        $system_type=$ref->{type};
        printf("scan system: type is %s\n",$system_type);
      }
      last; 
    }
  }
}
print "system_type=$system_type\n";

if($system_type eq "GPFS") {
  &LML_combine_obj_gpfs::update($filehandler->get_data_ref(),$opt_dbdir) if($opt_update);
}

# check if Cluster is a PBS controlled Altix SMP Cluster
if($system_type eq "Cluster") {
  keys(%{$filehandler->{DATA}->{OBJECT}}); # reset iterator
  my($key,$ref);
  while(($key,$ref)=each(%{$filehandler->{DATA}->{OBJECT}})) {
    if($ref->{type} eq 'node') {
      $ref=$filehandler->{DATA}->{INFODATA}->{$key};
      if(exists($ref->{ntype})) {
        if($ref->{ntype} eq "PBS") {
          $system_type="PBS";
          $system_type_ref->{type}="PBS";
          printf("scan system: type reset to %s\n",$system_type);
        }
      }
      last; 
    }
  }
}

if($system_type eq "Cluster") {
  &LML_combine_obj_cluster::update($filehandler->get_data_ref(),$opt_dbdir)  if($opt_update);
}
if($opt_jcheck) {
  &LML_combine_obj_check::check_jobs($filehandler->get_data_ref());
}

my $endtime=time();

if($opt_pstat) {
  my $pstat_num=1;
  my $pstat_name=sprintf("pstat_combine%d",$pstat_num);
  while(exists($filehandler->{DATA}->{OBJECT}->{$pstat_name})) {
    $pstat_name=sprintf("pstat_combine%d",++$pstat_num);
  }
  
  $filehandler->{DATA}->{OBJECT}->{$pstat_name}->{id}="$pstat_name";
  $filehandler->{DATA}->{OBJECT}->{$pstat_name}->{name}="$pstat_name";
  $filehandler->{DATA}->{OBJECT}->{$pstat_name}->{type}="pstat";
  $filehandler->{DATA}->{INFO}->{$pstat_name}->{oid}="$pstat_name";
  $filehandler->{DATA}->{INFO}->{$pstat_name}->{type}="short";
  $filehandler->{DATA}->{INFODATA}->{$pstat_name}->{startts}=sprintf("%.3f",$starttime);
  $filehandler->{DATA}->{INFODATA}->{$pstat_name}->{endts}=sprintf("%.3f",$endtime);
  $filehandler->{DATA}->{INFODATA}->{$pstat_name}->{duration}=sprintf("%.3f",$endtime-$starttime);
  $filehandler->{DATA}->{INFODATA}->{$pstat_name}->{nelem}=sprintf("%.d",scalar keys(%{$filehandler->{DATA}->{OBJECT}}) );
}
  
if($opt_verbose) {
  print $filehandler->get_stat();
}

#print ":$0: pstat=$opt_pstat\n";

# check if Cluster is a PBS controlled Altix SMP Cluster
if(!$opt_pstat) {
  keys(%{$filehandler->{DATA}->{OBJECT}}); # reset iterator
  my($key,$ref);
  while(($key,$ref)=each(%{$filehandler->{DATA}->{OBJECT}})) {
    if($ref->{type} eq 'pstat') {
      # print "$key $ref->{type}\n";
      delete($filehandler->{DATA}->{OBJECT}->{$key});
      delete($filehandler->{DATA}->{INFO}->{$key});
      delete($filehandler->{DATA}->{INFODATA}->{$key});
      # print "$0: removed $key (pstat)\n";
    }
  }
}

$filehandler->write_lml($opt_outfile);

sub usage {
  die "Usage: $_[0] <options> <filenames> 
                -output <file>           : LML output filename
                -verbose                 : verbose
                -(no)update              : update attributes (e.g. add in jobs aggr. node info)
                -keep    		 : keep objects with identical ID as separated objects				 
";
}
