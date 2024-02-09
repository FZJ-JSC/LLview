#!/usr/bin/perl -w 
#*******************************************************************************
#* Copyright (c) 2011 Forschungszentrum Juelich GmbH.
#* All rights reserved. This program and the accompanying materials
#* are made available under the terms of the Eclipse Public License v1.0
#* which accompanies this distribution, and is available at
#* http://www.eclipse.org/legal/epl-v10.html
#*
#* Contributors:
#*    Wolfgang Frings (Forschungszentrum Juelich GmbH) 
#*******************************************************************************/ 

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

use LML_da_util qw( check_folder );
use LL_jobreport;

my $patint="([\\+\\-\\d]+)";   # Pattern for Integer number
my $patfp ="([\\+\\-\\d.E]+)"; # Pattern for Floating Point number
my $patwrd="([\^\\s]+)";       # Pattern for Work (all noblank characters)
my $patbl ="\\s+";             # Pattern for blank space (variable length)

my $caller=$0; $caller=~s/^.*\/([^\/]+)$/$1/gs;
my $instname="[${caller}][PRIMARY]";

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
my $opt_demo=0;
my $opt_journalonly=0;
my $opt_journaldir=undef;
my $opt_parallel=4;
my $opt_maxfiles=50;
my $opt_type="compress";

usage($0) if( ! GetOptions( 
            'verbose'          => \$opt_verbose,
            'timings'          => \$opt_timings,
            'type=s'           => \$opt_type,
            'parallel=i'       => \$opt_parallel,
            'maxfiles=i'       => \$opt_maxfiles,
            'journalonly'      => \$opt_journalonly,
            'journaldir=s'     => \$opt_journaldir,
            'demo'             => \$opt_demo
            ) );


if ($opt_verbose) {
  printf("%s Parameters:\n",$instname);
  printf("%s  verbose            = %d\n",$instname,$opt_verbose);
  printf("%s  demo               = %d\n",$instname,$opt_demo);
  printf("%s  parallel           = %d\n",$instname,$opt_parallel);
  printf("%s  maxfiles           = %d\n",$instname,$opt_maxfiles);
  printf("%s  type               = %s\n",$instname,$opt_type);
  printf("%s  journalonly        = %s\n",$instname,$opt_journalonly);
  printf("%s  journaldir         = %s\n",$instname,$opt_journaldir); 
}

# set umask
umask 0022;

# get lastts to find dat files which are completed
my $journalsignalfile=sprintf("%s/mngt_actions_%s_lastts.dat",$opt_journaldir,$opt_type);
open(IN,$journalsignalfile) or die "Cannot open $journalsignalfile";
my $lastts=<IN>;chomp($lastts);
close(IN);

# check for files
opendir(JOURNALDIR,"$opt_journaldir") or die "Cannot open $opt_journaldir \n";
my @files = readdir(JOURNALDIR);
closedir(JOURNALDIR);

# search for dat files containing commands
my @cmdlist;
my $filestatus;
my $cmdcount=0;
my $filecount=0;
foreach my $file (sort (@files)) {
  if($file =~ /^mngt_actions_${opt_type}_$patint.dat$/) {
    $filecount++;
    last if($filecount>$opt_maxfiles);
    
    $filestatus->{$file}=1;
    print "$instname Found action file $file\n";
    open(IN,"$opt_journaldir/$file") or die "$instname Cannot open $opt_journaldir/$file";
    while(my $cmd=<IN>) {
      chomp($cmd);

      # if($cmd=~/^gzip (.*)$/) {
      #   my $zfile=$1;
      #   next if(!-f $zfile); 
      # }
      
      my $ref;
      $ref->{cmd}=$cmd;
      $ref->{file}=$file;
      push(@cmdlist,$ref);
      $cmdcount++;
    }
    close(IN);
  }
  print "$instname Found $cmdcount actions up to now\n";
}

my $pm = Parallel::ForkManager->new($opt_parallel);

# Setup a callback for when a child finishes up so we can get it's exit code
$pm->run_on_finish( sub {
                    my ($pid, $exit_code, $ident) = @_;
                    # print "finish: $pid returned with exit_code $exit_code (ident $ident)\n";
                    my($nr,$file)=split(":",$ident);
                    $filestatus->{$file}=0 if($exit_code != 0);
                  });
my $cnt=0;
DATA_LOOP:
  foreach my $cmdref (@cmdlist) {
    $cnt++;
    
    # Forks and returns the pid for the child:
    my $pid = $pm->start("$cnt:$cmdref->{file}") and next DATA_LOOP;
    my $ret=&mysystem($cmdref->{cmd});
    printf("%s [%d/%d] performed action from %s rc=%d\n",$instname,
            $cnt,$cmdcount,$cmdref->{file},$ret);
    if($ret !=0) {
      $pm->finish(1); # Terminates the child process
    } else {
      $pm->finish(0); # Terminates the child process
    }
  }
$pm->wait_all_children;

#print Dumper($filestatus);
&check_folder("$opt_journaldir/done/");
&check_folder("$opt_journaldir/errors/");

# remove action files
foreach my $file (sort(keys(%{$filestatus}))) {
  if($filestatus->{$file}) {
    print "$instname Remove file $file...\n";
    rename("$opt_journaldir/$file","$opt_journaldir/done/${file}-done");
    # unlink("$opt_journaldir/$file");
  } else {
    rename("$opt_journaldir/$file","$opt_journaldir/errors/${file}-with-errors");
  }
}

sub mysystem {
  my($call)=@_;

  printf("  --> exec: %s\n",$call) if($opt_verbose);
  system($call);
  my $rc = $?;
  if ($rc) {
    printf(STDERR "  ERROR --> exec: %s\n",$call);
    printf(STDERR "  ERROR --> rc=%d\n",$rc);
  } else {
    printf("           rc=%d\n",$rc) if($opt_verbose);
  }
  return($?)
}

sub usage {
  die "Usage: $_[0] <options> <filenames> 
        -config <file>           : YAML config file
        -verbose                 : verbose
";
}
