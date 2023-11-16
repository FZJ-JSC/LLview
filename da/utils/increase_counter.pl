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

use strict;
use Time::HiRes qw ( time );

my $cntfile = shift(@ARGV);

printf("[%s] cntfile  = %s\n",$0,$cntfile);

my $current_cnt=0;

if (-f $cntfile ) {
    $current_cnt=`cat $cntfile`;
}
$current_cnt++;
open(STEP, "> $cntfile") or die "cannot open $cntfile";
print STEP $current_cnt;
close(STEP);

printf("[%s] cnt  = %d \n",$0,$current_cnt);

exit;

