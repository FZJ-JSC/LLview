# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LML_combine_obj_gpfs;

use strict;
use Data::Dumper;

my @keylist = ( "r", "sw", "mw",
                "pfw", "ftw", "fuw", "fpw", "m",
                "s", "l", "fc", "fix", "ltr",
                "lhr", "rgd", "meta" );
my @fs = ( "work", "data", "home" );
my @type = ( "d", "m" );

sub update {
  my($dataptr) = shift;
  my($dbdir) = shift;
  my(%gpuoffsets);
  my ($nodeioinforef,$nodeusageref,$nodeinforef);

  $nodeioinforef=&get_node_io_info($dataptr);
  &update_nodeio_info($dataptr,$nodeioinforef);

  return(1);
} 


sub get_node_io_info {
  my($dataptr) = shift;
  my($dbdir) = shift;
  my($nodeusageref) = shift;
  my($id,$node,$jobref,$midplane,$row,$col,$iid,$nmidplane,$nnode,$nionode);
  my(%nodeioinfo,$nodeinfo,$ionode,%nodefactor,$stat);

  # get node io info
  foreach $id (keys(%{$dataptr->{OBJECT}})) {
    if($dataptr->{OBJECT}->{$id}->{type} eq "ionode") {
      $ionode=$dataptr->{OBJECT}->{$id}->{name};
      $nodeioinfo{$ionode}=$dataptr->{INFODATA}->{$id};

      # remove it from data structure
      delete($dataptr->{OBJECT}->{$id});
      delete($dataptr->{INFO}->{$id});
      delete($dataptr->{INFODATA}->{$id});
    }
  }

  return(\%nodeioinfo);
} 

sub update_nodeio_info {
  my($dataptr) = shift;
  my($nodeioinforef) = shift;
  my($id,$sid,$ref,$noderef,$nodename,%partitions,$skey,$fs,$type);

  # add environment attributes to nodes

  # scan for partition names
  foreach $id (keys(%{$dataptr->{OBJECT}})) {
    if($dataptr->{OBJECT}->{$id}->{type} eq "env") {
      $partitions{$dataptr->{OBJECT}->{$id}->{name}}=$dataptr->{INFODATA}->{$id};
    }
  }
  # update node info
  foreach $id (keys(%{$dataptr->{OBJECT}})) {
    if($dataptr->{OBJECT}->{$id}->{type} eq "node") {
      $noderef=$dataptr->{INFODATA}->{$id};
      $nodename=$dataptr->{OBJECT}->{$id}->{name};

      if($id eq "nd000001") {
        if(scalar keys(%{$nodeioinforef}) > 0) {
          for $fs (@fs) {
            for $type (@type) {
              for $skey (@keylist) {
                $noderef->{"${skey}_${fs}_${type}_MIN"}=0;
                $noderef->{"${skey}_${fs}_${type}_MAX"}=10000;  # todo: more sohisticated 
                $noderef->{"${skey}_${fs}_${type}_UNIT"}="ops"; # todo: more sohisticated 
              }
            }
          }
        }
      }

      if(exists($nodeioinforef->{$nodename})) {
        $ref=$nodeioinforef->{$nodename};
        print "TMPDEB: nodeioinforef->{$nodename}=$ref\n";
        
        # WORK
        for $skey (@keylist) {
          for $type (@type) {
            print "TMPDEB: ref->{${skey}_work_${type}}=",$ref->{"${skey}_work_${type}"},"\n";
            if(exists($ref->{"${skey}_work_${type}"})) { 
              if($ref->{"${skey}_work_${type}"}>0) {
                $noderef->{"${skey}_work_${type}"}=($ref->{"${skey}_work_${type}"});
              }
            }
          }
        }

        # DATA
        for $skey (@keylist) {
          for $type (@type) {
            if(exists($ref->{"${skey}_data_${type}"})) { 
              if($ref->{"${skey}_data_${type}"}>0) {
                $noderef->{"${skey}_data_${type}"}=($ref->{"${skey}_data_${type}"});
              }
            }
          }
        }

        # HOME
        for $skey (@keylist) {
          for $type (@type) {
            if( exists($ref->{"${skey}_homea_${type}"}) || exists($ref->{"${skey}_homeb_${type}"}) || exists($ref->{"${skey}_homec_${type}"}) ) { 
              if($ref->{"${skey}_homea_${type}"}>0) {
                $noderef->{"${skey}_home_${type}"}+=($ref->{"${skey}_homea_${type}"});
              }
              if($ref->{"${skey}_homeb_${type}"}>0) {
                $noderef->{"${skey}_home_${type}"}+=($ref->{"${skey}_homeb_${type}"});
              }
              if($ref->{"${skey}_homec_${type}"}>0) {
                $noderef->{"${skey}_home_${type}"}+=($ref->{"${skey}_homec_${type}"});
              }
            }
          }
        }
      }
    }
  }
  return(1);
}

1;
