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

sub read_CSV {
  my($self) = shift;
  my($filename)=@_;
  
  if(! -f $filename) {
    printf(STDERR "\n[LML_DBupdate_CVS_file] ERROR: file $filename not found, leaving...\n\n");
    return();
  }
  my $tag=$filename;
  $tag=~s/^.*\///s;
  $tag=~s/\.csv$//s;
  $tag=uc($tag)."_ENTRIES";
  # print "TMPDEB: tag: $filename -> $tag\n";
  
  open(CSV,$filename) or die "cannot open '$filename'";
  my $headerline=<CSV>;
  # print "TMPDEB: header: $headerline\n";
  $headerline=~s/^\s*\#//s;$headerline=~s/\n//gs;
  my @keys=split(',',$headerline);
  while(my $dataline=<CSV>) {
    $dataline=~s/\n//gs;
    # print "TMPDEB: dataline: $dataline\n";
    my @values=split(',',$dataline);
    my $ref;
    for(my $k=0;$k<=$#values;$k++) {
      $ref->{$keys[$k]}=$values[$k];
    }
    push(@{$self->{DATA}->{$tag}},$ref);
  }
  CORE::close(CSV);
  printf("\t[LML_DBupdate_CSV_file] read_CSV $filename\n") if($debug>=3);
  # print "TMPDEB:",Dumper($self->{DATA});
}

1;
