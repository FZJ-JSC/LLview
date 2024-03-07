# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LML_DBupdate_file;

my $VERSION='$Revision: 1.00 $';
my($debug)=0;

use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

my $patint="([\\+\\-\\d]+)";   # Pattern for Integer number
my $patfp ="([\\+\\-\\d.E]+)"; # Pattern for Floating Point number
my $patwrd="([\^\\s]+)";       # Pattern for Work (all noblank characters)
my $patbl ="\\s+";             # Pattern for blank space (variable length)

sub read_CSV {
  my($self) = shift;
  my($filename)=@_;
  
  if(! -f $filename) {
    printf(STDERR "\n[LML_DBupdate_CVS_file] ERROR: file $filename not found, leaving...\n\n");
    return();
  }
  my $tag=$filename;
  if($filename=~/db_$patwrd\_tab\_$patwrd\_date\_$patint\_w$patint\./) {
    $tag=$2;
  } else {
    $tag=~s/^.*\///s;
    $tag=~s/\.csv$//s;
  }
  $tag=uc($tag)."_ENTRIES";
  # print "TMPDEB: tag: $filename -> $tag\n";
  
  if($filename=~/.csv$/) {
    open(CSV,$filename) or die "cannot open '$filename'";
  } elsif($filename=~/.csv.xz$/) {
    open(CSV,"xzcat $filename|") or die "cannot open '$filename'";
  } elsif($filename=~/.csv.gz$/) {
    open(CSV,"zcat $filename|") or die "cannot open '$filename'";
  } else {
    printf(STDERR "\nLML_DBupdate_CVS_file: ERROR unknown file type extension $filename, leaving ...\n\n");
    return();
  }
  my @keys;
  my $firstline=<CSV>;
  #    print "TMPDEB: first line: $firstline\n";
  if($firstline=~/^\#DATE:/) {
    # it's a archived DB file, skip line
    $firstline=<CSV>; # COUNT:
    $firstline=<CSV>; # COLUMNS:
    if($firstline!~/^\#COLUMNS:/) {
      printf(STDERR "\nLML_DBupdate_CVS_file: ERROR no COLUMNS entry found in archDB CVS file $filename, leaving ...\n\n");
      return();
    }
    $firstline=~s/^\s*\#COLUMNS\: //s;$firstline=~s/\n//gs;
    @keys=split(',',$firstline);
  } else {
    # it's normal CSV file, first line contains header
    $firstline=~s/^\s*\#//s;$firstline=~s/\n//gs;
    @keys=split(',',$firstline);
  }
  my $numkeys=scalar @keys;
  printf("\t LML_DBupdate_CSV_file: #keys=%d (%s)\n",$numkeys,join(",",@keys)) if($debug>=0);
  my $count_lines=0;
  my $count_skipped=0;
  my $count_headers=1;
  while(my $dataline=<CSV>) {
    next if($dataline=~/^\#DATE:/);
    next if($dataline=~/^\#COUNT:/);
    if($dataline=~/^#COLUMNS:/) {
      $dataline=~s/^\s*\#COLUMNS\: //s;$dataline=~s/\n//gs;
      @keys=split(',',$dataline);
      $numkeys= scalar @keys;
      printf("\t LML_DBupdate_CSV_file: #keys=%d (%s)\n",$numkeys,join(",",@keys)) if($debug>=3);
      $count_headers++;
      next;
    }
    $dataline=~s/\n//gs;
    my @values=split(',',$dataline,-1);
    if( (scalar @values) != $numkeys) {
      printf(STDERR "\nLML_DBupdate_CVS_file: ERROR number of elements (%d) in line differs from #keys (%d), skipping line ($dataline) ...\n",(scalar @values), $numkeys);
      $count_skipped++;
      # print "TMPDEB: dataline (",scalar @values," [$numkeys]): $dataline\n";
      for(my $k=0;$k<=$#values;$k++) {
        printf(" [%3d] %-20s = %s\n",$k, $keys[$k],$values[$k]);
      }
      next;
    }
    my $ref;
    for(my $k=0;$k<=$#values;$k++) {
      $ref->{$keys[$k]}=$values[$k];
    }
    push(@{$self->{DATA}->{$tag}},$ref);
    $count_lines++;
    if($count_lines%25000==0) {
      $|=1;printf("LML_DBupdate_CVS_file: %6d lines processed (%d skipped, %d headers)\n",$count_lines,$count_skipped,$count_headers);$|=0;
    }
    #	last if($count_lines>50000);
  }
  CORE::close(CSV);
  printf("\t[LML_DBupdate_CSV_file] read_CSV $filename\n") if($debug>=3);
  # print "TMPDEB:",Dumper($self->{DATA});
}

1;
