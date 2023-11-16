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

#####################################################################
# get command line parameter
#####################################################################

# option handling
my $opt_indir="./testin";
my $opt_outdir="./testout";
my $opt_type  ="SSHdd";
my $opt_sshkey="";
my $opt_login ="";
my $opt_port ="";
my $opt_desthost ="";
my $opt_rsyncopts="";
my $opt_verbose=1;
my $opt_timings=0;
my $opt_exclude ="";
my $opt_dump=0;
usage($0) if( ! GetOptions( 
                'verbose'          => \$opt_verbose,
                'timings'          => \$opt_timings,
                'dump'             => \$opt_dump,
                'indir=s'          => \$opt_indir,
                'outdir=s'         => \$opt_outdir,
                'type=s'           => \$opt_type,
                'sshkey=s'         => \$opt_sshkey,
                'login=s'          => \$opt_login,
                'port=s'           => \$opt_port,
                'desthost=s'       => \$opt_desthost,
                'rsyncopts=s'      => \$opt_rsyncopts,
                'exclude=s'        => \$opt_exclude
                ) );

&usage($0) if(!$opt_indir);
&usage($0) if(!$opt_type);
&usage($0) if(!$opt_sshkey);
&usage($0) if(!$opt_login);
&usage($0) if(!$opt_port);
&usage($0) if(!$opt_desthost);
&usage($0) if(!$opt_rsyncopts);
&usage($0) if(!$opt_outdir);

if($opt_verbose) {
  printf("indir   = %s\n",$opt_indir);
  printf("outdir   = %s\n",$opt_outdir);
  printf("type     = %s\n",$opt_type);
  printf("sshkey   = %s\n",$opt_sshkey);
  printf("login    = %s\n",$opt_login);
  printf("port     = %s\n",$opt_port);
  printf("desthost = %s\n",$opt_desthost);
  printf("rsyncopts = %s\n",$opt_rsyncopts);
  printf("exclude   = %s\n",$opt_exclude);
}

my $tstart=time;
if($opt_type=~/DDSSH/) {
  _ddssh_rsync($opt_indir,$opt_outdir,$opt_sshkey,$opt_port,$opt_login,$opt_desthost,$opt_rsyncopts,$opt_exclude,$opt_verbose);
}
my $tend=time();
my $trun=sprintf("%14.6f",$tend-$tstart);

print "transfertime: $trun ($tstart,$tend)\n";

sub _ddssh_rsync {
  my($indir,$outdir,$keyfile,$port,$login,$server,$rsyncopts,$exclude,$verbose)=@_;
  my $rc=0;

  my $excludeopts="";
  $excludeopts="--exclude \'$exclude\'" if($exclude); 
  my $cmd="rsync -e \"ssh -p $port -i $keyfile\" $rsyncopts $excludeopts $indir $login"."\@"."$server:$outdir";

  printf "executing: %s\n",$cmd if($verbose);
  system($cmd);$rc=$?;
  if($rc) {
    printf STDERR "failed executing: %s rc=%d\n",$cmd,$rc; 
    exit(-1);
  }
  return($rc);
}


sub usage {
  die "Usage: $_[0] <options> <filenames> 
                -verbose                 : verbose
                -indir <dir>             : input directory
                -outdir <dir>            : output directory on remote system
                -type <type>             : transfertype (DDSSH)
                -sshkey <keyfile>        : ssh keyfile             
                -login <id>              : login name on remote system
                -port <num>              : port number (22)
                -desthost <hostname>     : remote host
                -rsyncopts <hostname>    : options for rsync

        Initial steps:
        --> generate two keys:
          > ssh-keygen -t rsa -N '' -C 'LML data transport to <host>' -f <keyfile>
          and store private keys somewhere in a directory not readable for others ...
        --> add following lines to .ssh/authorized_keys on remote host
          command=<path_to_rrsync>/rrsync.pl -wo <path>\",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding ssh-rsa
          ...
";
}
