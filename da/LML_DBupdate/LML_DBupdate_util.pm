# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LML_DBupdate;
use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

my $patint="([\\+\\-\\d]+)";   # Pattern for Integer number
my $patfp ="([\\+\\-\\d.E]+)"; # Pattern for Floating Point number
my $patwrd="([\^\\s]+)";       # Pattern for Work (all noblank characters)
my $patbl ="\\s+";             # Pattern for blank space (variable length)


sub date_to_sec {
  my ($ldate)=@_;
  my ($year,$mon,$mday,$hours,$min,$sec)=split(/[ :\/\-\_\.T]/,$ldate);
  $mon--;
  $sec=0 if(!defined($sec));
  # print "TMPDEB: date_to_sec $ldate -> sec=$sec,min=$min,hours=$hours,mday=$mday,mon=$mon,year=$year\n";
  my $timesec=timelocal($sec,$min,$hours,$mday,$mon,$year);
  return($timesec);
}

sub cutdigits6 {
  my($fp)=@_;
  return( int($fp*100000) / 100000.0 );
}

sub _max {
  my ( $a, $b ) = @_;
  if ( not defined $a ) { return $b; }
  if ( not defined $b ) { return $a; }
  if ( not defined $a and not defined $b ) { return; }

  if   ( $a >= $b ) { return $a; }
  else              { return $b; }

  return;
}

sub _min {
  my ( $a, $b ) = @_;
  if ( not defined $a ) { return $b; }
  if ( not defined $b ) { return $a; }
  if ( not defined $a and not defined $b ) { return; }

  if   ( $a <= $b ) { return $a; }
  else              { return $b; }

  return;
}

1;