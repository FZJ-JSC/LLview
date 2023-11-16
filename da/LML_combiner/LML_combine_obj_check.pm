# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LML_combine_obj_check;

use strict;
use Data::Dumper;
use lib "$FindBin::RealBin/../LML_specs";
use LML_specs;
use lib "$FindBin::RealBin/../lib";
use LML_da_date_manip;

my($debug)=0;

sub check_jobs {
  my($dataptr) = shift;
  my($inforef,$id,$key);
  my(%unknown_attr,%unset_attr);

  foreach $id (keys(%{$dataptr->{OBJECT}})) {
  if($dataptr->{OBJECT}->{$id}->{type} eq "job") {
    $inforef=$dataptr->{INFODATA}->{$id};
    foreach $key (keys %{$inforef}) {
      if(!exists($LML_specs::LMLattributes->{'job'}->{$key})) {
        $unknown_attr{$key}++;
      } else {
        # modify dates to std format
        if($LML_specs::LMLattributes->{'job'}->{$key}->[0] eq "D") {
          if($dataptr->{INFODATA}->{$id}->{$key} ne '') {
            $dataptr->{INFODATA}->{$id}->{$key}=&LML_da_date_manip::date_to_stddate($dataptr->{INFODATA}->{$id}->{$key});
          } else {
            print "WARN: check_jobs: no attribute value for dataptr->{INFODATA}->{$id}->{$key}\n" if($debug>0);
          }
        }
      }
    }
    foreach $key (keys %{$LML_specs::LMLattributes->{'job'}}) {
      next if ($LML_specs::LMLattributes->{'job'}->{$key}->[1] ne "M");
      if(!exists($inforef->{$key})) {
        $unset_attr{$key}++;
      }
    }

  }
  }
  foreach $key (sort keys(%unknown_attr)) {
    printf("check_jobs: WARNING: unknown attribute '%s' %d occurrences\n",$key,$unknown_attr{$key});
  }
  foreach $key (sort keys(%unset_attr)) {
    printf("check_jobs: WARNING: unset attribute '%s' %d occurrences\n",$key,$unset_attr{$key});
  }
  
  return(1);
} 

1;