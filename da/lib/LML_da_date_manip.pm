# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LML_da_date_manip;

use Time::Local;
use Data::Dumper;

my %monthmap= ( 'Jan' => 1, 'Feb' => 2, 'Mar' => 3, 'Apr' => 4, 'May'=> 5, 'Jun' => 6, 
                'Jul' => 7, 'Aug' => 8, 'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12 );

sub date_to_stddate {
  my($indate)=@_;
  my($outdate);
  my($sec,$min,$hour,$mday,$mon,$year);

  if($indate=~/^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/) {
    return($indate);
  }
  if($indate=~/^\w\w\w\s+(\w\w\w)\s+(\d+)\s+(\d\d):(\d\d):(\d\d)\s+(\d\d\d\d)$/) {
    ($sec,$min,$hour,$mday,$mon,$year)=($5,$4,$3,$2,$1,$6);
    $outdate=sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year,$monthmap{$mon},$mday,$hour,$min,$sec);
    return($outdate);
  } 

  if($indate=~/^\w\w\w\s+(\w\w\w)\s+(\d+)\s+(\d\d):(\d\d):(\d\d)\s+(CEST)\s+(\d\d\d\d)$/) {
    ($sec,$min,$hour,$mday,$mon,$year)=($5,$4,$3,$2,$1,$7);
    $outdate=sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year,$monthmap{$mon},$mday,$hour,$min,$sec);
    return($outdate);
  } 
  if($indate=~/^\w\w\w\s+(\d+)\s+(\w\w\w)\s+(\d\d\d\d)\s+(\d\d):(\d\d):(\d\d)\s+(CES?T)$/) {
    ($sec,$min,$hour,$mday,$mon,$year)=($6,$5,$4,$1,$2,$3);
    $outdate=sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year,$monthmap{$mon},$mday,$hour,$min,$sec);
    return($outdate);
  } 
  if($indate=~/^\w\w\w\s+(\d+)\s+(\w\w\w)\s+(\d\d\d\d)\s+(\d\d):(\d\d):(\d\d)\s+(CET)$/) {
    ($sec,$min,$hour,$mday,$mon,$year)=($6,$5,$4,$1,$2,$3);
    $outdate=sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year,$monthmap{$mon},$mday,$hour,$min,$sec);
    return($outdate);
  } 
  if($indate=~/^(\d\d)\/(\d\d)\/(\d\d)[- ](\d\d):(\d\d):(\d\d)$/) {
    ($sec,$min,$hour,$mday,$mon,$year)=($6,$5,$4,$2,$1,$3);
    $outdate=sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year,$mon,$mday,$hour,$min,$sec);
    return($outdate);
  }
  #Date having only hour, minute and second. Use the current local time for the date.
  if($indate=~/^(\d\d):(\d\d):(\d\d)$/) {
    my ($csec,$cmin,$chour,$cmday,$cmon,$cyear,$cwday,$cyday,$cidst)=localtime(time());
    $cyear = $cyear+1900;
    $cmon = $cmon+1;
    ($sec,$min,$hour,$mday,$mon,$year) = ($3,$2,$1,$cmday,$cmon,$cyear); 
    $outdate=sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year,$mon,$mday,$hour,$min,$sec);
    return($outdate);
  }
  print STDERR "ERROR: date_to_stddate: could not convert date  '$indate' -> ?",caller(),"\n";
  return($indate);
}

sub date_to_llviewdate {
  my($indate)=@_;
  my($stddate,$outdate);
  
  if(!defined($indate) ){
    return "";
  }
  
  $stddate=&date_to_stddate($indate);
  $stddate=~/^\d\d(\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/;
  ($sec,$min,$hour,$mday,$mon,$year)=($6,$5,$4,$3,$2,$1);
  
  if(!defined($sec)){
    $sec=1;
  }
  if(!defined($min)){
    $min=1;
  }
  if(!defined($hour)){
    $hour=1;
  }
  if(!defined($mday)){
    $mday=1;
  }
  if(!defined($mon)){
    $mon=1;
  }
  if(!defined($year)){
    $year=1;
  }
  
  $outdate=sprintf("%02d/%02d/%02d %02d:%02d:%02d",$mon,$mday,$year,$hour,$min,$sec);

  return($outdate);
}


sub time_to_stdduration {
  my($intime)=@_;
  my($outdate);
  my($sec,$min,$hour,$day);

  if($indate=~/^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/) {
    return($indate);
  }
  if($indate=~/^\w\w\w\s+(\w\w\w)\s+(\d+)\s+(\d\d):(\d\d):(\d\d)\s+(\d\d\d\d)$/) {
    ($sec,$min,$hour,$mday,$mon,$year)=($5,$4,$3,$2,$1,$6);
    $outdate=sprintf("%02d/%02d/%02d %02d:%02d:%02d",$monthmap{$mon},$mday,$year,$hour,$min,$sec);
    return($outdate);
  } 
  print STDERR "ERROR: date_to_stddate: could not convert date  '$indate' -> ?",caller(),"\n";
  return($indate);
}


#*****************************************************************
#
# @return the current local time in the format 
#			$year-$month-$day $hour:$min:$sec, 
#			e.g. 2014-03-28 15:16:10
#
#*****************************************************************
sub getCurrentDate{
  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$idst)=localtime(time());

  $mon+=1;
  $year+=1900;
  return sprintf("%04d-%02d-%02d %02d:%02d:%02d\n", $year, $mon, $mday, $hour, $min, $sec);
}


1;
