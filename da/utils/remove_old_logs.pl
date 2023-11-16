#!/usr/bin/perl -w
# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Filipe Guimarães (Forschungszentrum Juelich GmbH) 

# This script uses the internal remove_old_logs function (defined in da/lib/LML_da_util.pm)
# To clean logs older than $ENV{'LLVIEW_LOG_DAYS'} days defined in the config .llview_server_rc
# (when that is not defined, default is 1)
use strict;
# Use internal library
use FindBin;
use lib "$FindBin::RealBin/../lib";
use LML_da_util qw( remove_old_logs );

my $folder = $ARGV[0];  # Folder to clean the logs

my $logdays = ($ENV{'LLVIEW_LOG_DAYS'}) ? $ENV{'LLVIEW_LOG_DAYS'} : 1;
&remove_old_logs($folder,$logdays);

exit;
