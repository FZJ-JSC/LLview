#!/usr/bin/perl
# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Carsten Karbach (Forschungszentrum Juelich GmbH) 
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 
#    Filipe Guimarães (Forschungszentrum Juelich GmbH) 

use strict;
# Use internal library
use FindBin;
use lib "$FindBin::RealBin/../../../lib";
use LML_da_util qw( get_date remove_old_logs check_folder );

# Folder definitions
my $system = $ENV{'LLVIEW_SYSTEMNAME'}; 
my $llview = $ENV{'LLVIEW_HOME'};
my $data = $ENV{'LLVIEW_DATA'};
my $conf = $ENV{'LLVIEW_CONF'};
my $prefix = "log_crontab"; # prefix for log/err files

# Defining log and error files
my $logs="$data/$system/logs/";
# Checking if logs folder exist, and if not, creates it
&check_folder($logs);
my $logfile = "$logs/$prefix.".&get_date().".log";
my $errfile = "$logs/$prefix.".&get_date().".errlog";

# If signal file exists, does not run any job
my $shutdown = $ENV{'LLVIEW_SHUTDOWN'} ? $ENV{'LLVIEW_SHUTDOWN'} : "$ENV{HOME}/HALT_ALL";
if(-f $shutdown) {
  my $cmd = qq{cd $logs; echo "[`date +'%D %T'`] Shutdown file $shutdown found. Exiting..." >> $logfile };
  system($cmd);
  exit;
}

system("env > $logs/last_run");
system("cd $data/$system; perl $llview/da/LML_da.pl --nostepfile -v -conf $conf/remote/workflows/LML_da_slurm.conf 1>> $logfile 2>> $errfile");


# Removing older log/err files (older than days defined in $LLVIEW_LOG_DAYS in .llview_remote_rc)
my $logdays = ($ENV{'LLVIEW_LOG_DAYS'} =~ '^[0-9]+$') ? $ENV{'LLVIEW_LOG_DAYS'} : 1;
&remove_old_logs($logs,$logdays,$logfile);
