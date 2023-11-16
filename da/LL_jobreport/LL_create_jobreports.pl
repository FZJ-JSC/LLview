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
use warnings::unused;
use Getopt::Long;
use Data::Dumper;
$Data::Dumper::Sortkeys=1;
use Time::Local;
use Time::HiRes qw ( time sleep );

use FindBin;
use lib "$FindBin::RealBin/";
use lib "$FindBin::RealBin/../lib";
use lib "$FindBin::RealBin/../LLmonDB";
use LLmonDB;
use LML_da_util qw( sec_to_date logmsg check_folder );

use LL_convert;
use LL_jobreport;

my $caller=$0;$caller=~s/^.*\/([^\/]+)$/$1/gs;
my $instname="[${caller}][PRIMARY]";
my $msg;

#####################################################################
# get command line parameter
#####################################################################

# option handling
my $opt_verbose=0;
my $opt_config=undef;
my $opt_updateconfig=0;
my $opt_demo=0;
my $opt_dbdir=undef;
my $opt_outdir=undef;
my $opt_tmpdir=undef;
my $opt_parallel=0;
my $opt_maxproc=8;
my $opt_parwaitsec=300;
my $opt_archdir=undef;
my $opt_currentts=undef;
my $opt_currenttsfile=undef;
my $opt_systemname=undef;

usage($0) if( ! GetOptions( 
                'verbose'          => \$opt_verbose,
                'demo!'            => \$opt_demo,
                'parallel!'        => \$opt_parallel,
                'parwaitsec=i'     => \$opt_parwaitsec,
                'config=s'         => \$opt_config,
                'updateconfig!'    => \$opt_updateconfig,
                'dbdir=s'          => \$opt_dbdir,
                'outdir=s'         => \$opt_outdir,
                'tmpdir=s'         => \$opt_tmpdir,
                'archdir=s'        => \$opt_archdir,
                'maxprocesses=i'   => \$opt_maxproc,
                'systemname=s'     => \$opt_systemname,
                'currentts=i'      => \$opt_currentts,
                'currenttsfile=s'  => \$opt_currenttsfile
              ) );

if (! defined($opt_dbdir)) {
  &usage($0);
}

if(! -f $opt_config) {
  $msg=sprintf("$instname Config-file $opt_config does not exist, aborting...\n"); logmsg($msg,\*STDERR);
  usage($0);
  exit;
}

&check_folder($opt_outdir.'/');

&check_folder($opt_tmpdir.'/');

my $currentts=time();
if (defined($opt_currenttsfile)) {
  if(-f $opt_currenttsfile) {
    open(IN,$opt_currenttsfile) or die "cannot open $opt_currenttsfile";
    $currentts=<IN>;chomp($currentts);
    close(IN);
  }
} elsif(defined($opt_currentts)) {
  $currentts=$opt_currentts;
}

my ($starttime,$endtime);

$msg=sprintf("%s %s\n",$instname,"*"x60); logmsg($msg);
$msg=sprintf("%s * %-56s *\n",$instname,"Start processing LLview JobReport"); logmsg($msg);
$msg=sprintf("%s %s\n",$instname,"*"x60); logmsg($msg);

$starttime=time();
$msg=sprintf("%s starttime_ts %d\n",$instname,$starttime); logmsg($msg);

if ($opt_verbose) {
  printf("%s Parameters:\n",$instname);
  printf("%s  verbose            = %d\n",$instname,$opt_verbose);
  printf("%s  demo               = %d\n",$instname,$opt_demo);
  printf("%s  config             = %s\n",$instname,$opt_config);
  printf("%s  parallel           = %d\n",$instname,$opt_parallel);
  printf("%s  parwaitsec         = %d\n",$instname,$opt_parwaitsec);
  printf("%s  db-dir             = %s\n",$instname,$opt_dbdir);
  printf("%s  outdir             = %s\n",$instname,$opt_outdir);
  printf("%s  tmpdir             = %s\n",$instname,$opt_tmpdir);
  printf("%s  archdir            = %s\n",$instname,$opt_archdir);
  printf("%s  systemname         = %s\n",$instname,$opt_systemname);
  printf("%s  opt_currentts      = %s\n",$instname,$opt_currentts) if(defined($opt_currentts));
  printf("%s  opt_currenttsfile  = %s\n",$instname,$opt_currenttsfile) if(defined($opt_currenttsfile));
  printf("%s  currenttime        = %s (%d)\n",$instname,&sec_to_date($currentts),$currentts);
}

# set umask
umask 0022;

my $jobreport=LML_jobreport->new($opt_verbose,$instname,$caller,$opt_outdir,$opt_updateconfig,$currentts,$opt_systemname);
if(0) {
  $jobreport->set_options(
  {
    # 'create_all_nodefiles' => $opt_extplot
  }
  );
}

# read DB  config 
my $DB;
$DB = LLmonDB->new($opt_config,$opt_dbdir,undef,$opt_verbose,$opt_systemname,$currentts);
$DB->init();
$endtime=time();
$msg=sprintf("%s openDB                                          in %7.4fs (ts=%.5f,%.5f,l=1,nr=1)\n",$jobreport->{INSTNAME},$endtime-$starttime,,$starttime,$endtime); logmsg($msg);
$jobreport->update_global_vars_in_config($DB,$opt_outdir,$opt_archdir,$opt_dbdir);  

$starttime=time();
$DB->process_collectDB_update("LLjobreport");  
$DB->close_dbs();
$endtime=time();
$msg=sprintf("%s collect_new_info                                in %7.4fs (ts=%.5f,%.5f,l=1,nr=2)\n",$jobreport->{INSTNAME},$endtime-$starttime,,$starttime,$endtime); logmsg($msg);

$starttime=time();
$jobreport->update_vars_from_DB($DB);  
$DB->close_dbs();
$endtime=time();
$msg=sprintf("%s update_var                                      in %7.4fs (ts=%.5f,%.5f,l=1,nr=3)\n",$jobreport->{INSTNAME},$endtime-$starttime,,$starttime,$endtime); logmsg($msg);

$starttime=time();
$jobreport->create_directories($DB);  
$DB->close_dbs();
$endtime=time();
$msg=sprintf("%s create_dir                                      in %7.4fs (ts=%.5f,%.5f,l=1,nr=4)\n",$jobreport->{INSTNAME},$endtime-$starttime,,$starttime,$endtime); logmsg($msg);

#open(DUMP,"> var.dat");
#print DUMP Dumper($jobreport->{VARS}->{'VAR_project_user_job'});
#close(DUMP);
#exit;

# close internal DBs, because next step is parallel and each process will open DBs individually 
$starttime=time();
$jobreport->create_datasets($DB,$opt_maxproc);  
$DB->close_dbs();
$endtime=time();
$msg=sprintf("%s create_datasets                                 in %7.4fs (ts=%.5f,%.5f,l=1,nr=5)\n",$jobreport->{INSTNAME},$endtime-$starttime,,$starttime,$endtime); logmsg($msg);

$starttime=time();
$jobreport->create_footerfiles($DB);  
$DB->close_dbs();
$endtime=time();
$msg=sprintf("%s create_footer                                   in %7.4fs (ts=%.5f,%.5f,l=1,nr=6)\n",$jobreport->{INSTNAME},$endtime-$starttime,,$starttime,$endtime); logmsg($msg);

$starttime=time();
$jobreport->create_graphpages($DB);  
$DB->close_dbs();
$endtime=time();
$msg=sprintf("%s create_graphpages                               in %7.4fs (ts=%.5f,%.5f,l=1,nr=7)\n",$jobreport->{INSTNAME},$endtime-$starttime,,$starttime,$endtime); logmsg($msg);

$starttime=time();
$jobreport->create_views($DB);  
$DB->close_dbs();
$endtime=time();
$msg=sprintf("%s create_views                                    in %7.4fs (ts=%.5f,%.5f,l=1,nr=8)\n",$jobreport->{INSTNAME},$endtime-$starttime,,$starttime,$endtime); logmsg($msg);

$msg=sprintf("%s %s\n",$jobreport->{INSTNAME},"*"x60); logmsg($msg);
$msg=sprintf("%s * %-56s *\n",$jobreport->{INSTNAME},"End processing LLview JobReport"); logmsg($msg);
$msg=sprintf("%s %s\n",$jobreport->{INSTNAME},"*"x60); logmsg($msg);
$endtime=time();
$msg=sprintf("%s endtime_ts %d\n",$jobreport->{INSTNAME},time()); logmsg($msg);

exit;

sub usage {
  die "Usage: $_[0] <options>
        --verbose                   : verbose
        --(no)parallel              : parallelism for different steps in execution (default no)
        --dbdir <dir>               : directory containing DB-files
        --outdir <dir>              : directory for output directory structure
        --tmpdir <dir>              : directory for temporary data
        --archdir <dir>             : directory for storing old file (> 2 weeks)
        --systemname <name>         : name of the system
        --maxprocesses              : max number of processes used in DB processing (default: 8)
        --config <file>             : configuration file with description of database to be used (YAML)
        --demo                      : generates addition directory containing anonymized data
        --parwaitsec <sec>          : parallel processing, timeout for subprocesses
";
}
