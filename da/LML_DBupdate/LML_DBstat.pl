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

use LML_file_obj;
use LML_da_util qw(sec_to_date);

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
my $opt_tmpdir=undef;
my $opt_lmlfile=undef;
my $opt_outfile=undef;
my $opt_dblist=undef;
my $caller=$0;$caller=~s/^.*\/([^\/]+)$/$1/gs;
my $instname="[${caller}][PRIMARY]";

usage($0) if( ! GetOptions( 
                          'verbose'          => \$opt_verbose,
                          'timings'          => \$opt_timings,
                          'config=s'         => \$opt_config,
                          'dbdir=s'          => \$opt_dbdir,
                          'tmpdir=s'         => \$opt_tmpdir,
                          'dblist=s'         => \$opt_dblist,
                          'lmlfile=s'        => \$opt_lmlfile,
                          'outfile=s'        => \$opt_outfile,
                          'maxprocesses=i'   => \$opt_maxproc,
                          'dump'             => \$opt_dump,
                          'demo'             => \$opt_demo
                          ) );


if(! -f $opt_config) {
  print "config-file $opt_config does not exist, leaving...\n";
  usage($0);
  exit;
}

my $DB;

my $starttime=time();
$DB = LLmonDB->new($opt_config,$opt_dbdir,undef,$opt_verbose);
$DB->init();
printf("%s open DB                                         in %7.4fs\n",$instname,time()-$starttime);

$starttime=time();
my $dbstat=$DB->DBstat($opt_dblist,$opt_tmpdir,$opt_maxproc);
printf("%s get table sizes                                 in %7.4fs\n",$instname,time()-$starttime);

$starttime=time();
my $dbgraphtime=time();
my $md_data_hash=$DB->get_graphsDB();
printf("%s: get dependency graphs                           in %7.4fs\n",$instname,time()-$starttime);

#print Dumper($dbstat);

if($opt_outfile) {
  $starttime=time();
  open(OUT, "> $opt_outfile") or die "cannot open $opt_outfile";
  foreach my $db (sort(keys(%{$dbstat}))) {
    foreach my $table (sort(keys(%{$dbstat->{$db}}))) {
      printf(OUT " %s: %-35s %-35s -> %8d rows\n",
                  sec_to_date($dbstat->{$db}->{$table}->{ts}),
                  $db,$table,
                  $dbstat->{$db}->{$table}->{nrows}
                );
    }
  }
  close(OUT);
  printf("%s generate OUT data                              in %7.4fs %s\n",$instname,time()-$starttime,$opt_outfile);
}
if($opt_lmlfile) {
  printf("%s generate %s\n",$instname,$opt_lmlfile);

  $starttime=time();
  my $filehandler=LML_file_obj->new($opt_verbose,$opt_timings);

  $filehandler->{DATA}->{OBJECT}->{pstat_DBstat}->{type}="pstat";
  $filehandler->{DATA}->{OBJECT}->{pstat_DBstat}->{name}="DBstat";
  $filehandler->{DATA}->{OBJECT}->{pstat_DBstat}->{id}="pstat_dbstat";
  $filehandler->{DATA}->{INFO}->{pstat_DBstat}->{oid}="pstat_dbstat";
  $filehandler->{DATA}->{INFO}->{pstat_DBstat}->{type}="short";
  $filehandler->{DATA}->{INFODATA}->{pstat_DBstat}->{startts}=time();

  my $cnt=0;
  foreach my $db (sort(keys(%{$dbstat}))) {
    foreach my $table (sort(keys(%{$dbstat->{$db}}))) {
      my $tabpath=$dbstat->{$db}->{$table}->{tabpath};
      $tabpath=~s/\//:/gs;
      $cnt++;
      my $id=sprintf("db%06d",$cnt);
      $filehandler->{DATA}->{OBJECT}->{$id}->{type}="DBstat";
      $filehandler->{DATA}->{OBJECT}->{$id}->{id}="$id";
      $filehandler->{DATA}->{OBJECT}->{$id}->{name}=$id;
      $filehandler->{DATA}->{INFO}->{$id}->{oid}=$id;
      $filehandler->{DATA}->{INFO}->{$id}->{type}="short";
      $filehandler->{DATA}->{INFODATA}->{$id}->{ts}=$dbstat->{$db}->{$table}->{ts};
      $filehandler->{DATA}->{INFODATA}->{$id}->{ts_min}=$dbstat->{$db}->{$table}->{ts_min};
      $filehandler->{DATA}->{INFODATA}->{$id}->{ts_max}=$dbstat->{$db}->{$table}->{ts_max};
      $filehandler->{DATA}->{INFODATA}->{$id}->{ts_dur}=$dbstat->{$db}->{$table}->{ts_dur};
      $filehandler->{DATA}->{INFODATA}->{$id}->{db}=$dbstat->{$db}->{$table}->{db};
      $filehandler->{DATA}->{INFODATA}->{$id}->{table}=$dbstat->{$db}->{$table}->{table};
      $filehandler->{DATA}->{INFODATA}->{$id}->{tabpath}=$dbstat->{$db}->{$table}->{tabpath};
      $filehandler->{DATA}->{INFODATA}->{$id}->{nrows}=$dbstat->{$db}->{$table}->{nrows};
      $filehandler->{DATA}->{INFODATA}->{$id}->{time_aggr_res}=$dbstat->{$db}->{$table}->{time_aggr_res};
    }
  }

  $cnt=0;
  foreach my $db (sort(keys(%{$md_data_hash}))) {
    $cnt++;
    my $id=sprintf("dbg%06d",$cnt);
    $filehandler->{DATA}->{OBJECT}->{$id}->{type}="DBgraph";
    $filehandler->{DATA}->{OBJECT}->{$id}->{id}="$id";
    $filehandler->{DATA}->{OBJECT}->{$id}->{name}=$id;
    $filehandler->{DATA}->{INFO}->{$id}->{oid}=$id;
    $filehandler->{DATA}->{INFO}->{$id}->{type}="short";
    $filehandler->{DATA}->{INFODATA}->{$id}->{ts}=$dbgraphtime;
    $filehandler->{DATA}->{INFODATA}->{$id}->{db}=$db;
    my $help=$md_data_hash->{$db}->{md};
    $help=~s/\n/ /gs;$help=~s/\t/ /gs;
    $filehandler->{DATA}->{INFODATA}->{$id}->{nlinks}=$md_data_hash->{$db}->{nlinks};
    $filehandler->{DATA}->{INFODATA}->{$id}->{ntabs}=$md_data_hash->{$db}->{ntabs};
    $filehandler->{DATA}->{INFODATA}->{$id}->{LMLattr}=$md_data_hash->{$db}->{LMLattr};
    $filehandler->{DATA}->{INFODATA}->{$id}->{graph}=$help;
  }

  if($opt_verbose) {
    print $filehandler->get_stat();
  }
  $filehandler->write_lml($opt_lmlfile);

  printf("%s generate LML data                              in %7.4fs\n",$instname,time()-$starttime);
}

$DB->close();  


sub usage {
  die "Usage: $_[0] <options> <filenames> 
              -config <file>           : YAML config file
              -lmlfile <file>          : generate LML output file containing DB stat info
              -verbose                 : verbose
              -maxprocesses            : max number of processes used (default: 8)
";
}
