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
# This script runs a $command every $niter times (i.e., every multiple of $niter)
# while on the other times it just copies an empty file $emptyfilefrom to $emptyfileto
use strict;
use Time::HiRes qw ( time );
use FindBin;
use lib "$FindBin::RealBin/../lib";
use LML_da_util qw( check_folder );

my $PRIMARKER="exec_every_n_step_or_empty.pl"; #$0

my $stepfile = shift(@ARGV);      # File that store the number of iterations
my $niter    = shift(@ARGV);      # Number of iterations to run the command
my $emptyfilefrom = shift(@ARGV); # Empty files to be copied every other iteration (non-multiples of $niter)
my $emptyfileto   = shift(@ARGV); # Final empty file (copied from previous argument)
my $command = join(" ",@ARGV);    # Command to be run every iteration multiple of $niter

# Logging input arguments
printf("[%s] stepfile = %s\n",$PRIMARKER,$stepfile);
printf("[%s] niter    = %d\n",$PRIMARKER,$niter);
printf("[%s] empty    = %s -> %s\n",$PRIMARKER,$emptyfilefrom,$emptyfileto);
printf("[%s] command  = %s\n",$PRIMARKER,$command);

# Starting iteration with zero
my $current_step=0;

# If file to store number of iteration exists, read number of iterations
if (-f $stepfile ) {
  $current_step=`cat $stepfile`;
}
# Adding current step and restarting count if needed
$current_step = ++$current_step % $niter;
# Saving new counter to file
open(STEP, "> $stepfile") or die "cannot open $stepfile";
print STEP $current_step;
close(STEP);

printf("[%s] current  = %d of %d\n",$PRIMARKER,$current_step % $niter,$niter);

# Rewriting command in case iteration is not a multiple of $niter
if($current_step != 0) {
  &check_folder($emptyfileto);
  $command="cp $emptyfilefrom $emptyfileto";
}
printf("[%s] Executing: %s\n",$PRIMARKER,$command);
system($command);

exit;
