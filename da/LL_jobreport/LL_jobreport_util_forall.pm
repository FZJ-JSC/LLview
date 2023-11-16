# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LML_jobreport;

my $VERSION='$Revision: 1.00 $';
my($debug)=0;

use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

sub process_FORALL {
  my $self = shift;
  my($DB,$forall,$varsetref,$func_ref,$funcpar)=@_;

  printf("process_FORALL: start\n") if($debug);

  return if(!exists($forall->{FORALL}));
  my $loopvar=$forall->{FORALL};
  printf("process_FORALL: loopvar=%s\n",$loopvar) if($debug);

  return if(!defined($funcpar));
  printf("process_FORALL: funcpar=%s\n",$funcpar) if($debug);
  
  my($varlist,$dbvar)=split(":",$loopvar);
  my @vars=split(",",$varlist);
  my $dbvarref;
  if($dbvar=~/\(([^\)]+)\)/) {
    my $list=$1;
    foreach my $k (split(/\s*,\s*/,$list)) {
      $dbvarref->{$k}=1;
    }
  } else {
    if($self->check_var_from_DB($DB,$dbvar)) {
      $dbvarref=$self->{VARS}->{$dbvar}->{data};
    } else {
      printf("%s process_FORALL: WARNING problems with var: %s\n",$self->{INSTNAME}, $dbvar);
    }
  }
  
  # start recursion
  &_process_FORALL($self,\@vars,$varsetref,$dbvarref,$func_ref,$funcpar);

  printf("process_FORALL: end\n") if($debug);
}

sub _process_FORALL {
  my $self = shift;
  my($varsref,$varsetref,$dbvarref,$func_ref,$funcpar)=@_;

  # printf("_process_FORALL: start vars='%s'\n",join(",",@{$varsref})) if($debug);

  if( defined($varsref) && (@{$varsref} > 0) ) {
    # copy varset for recursion
    my $localvarsetref;
    while ( my ($key, $value) = each(%{$varsetref}) ) {
      $localvarsetref->{$key}=$value;
    }

    # get first var and the associated values
    my @vars=(@{$varsref});
    my $v=shift(@vars);
    my @valuelist=keys(%{$dbvarref});

    printf("_process_FORALL: loop var=%s vars='%s' #keys=%d\n",$v,join(",",@vars), scalar @valuelist) if($debug);
    # start recursion again
    foreach my $value (sort(@valuelist)) {
      $localvarsetref->{$v}=$value;
      &_process_FORALL($self,\@vars,$localvarsetref,$dbvarref->{$value},$func_ref,$funcpar);
      # last; # debug
    }
  } else {
    # end of recursion
  
    # printf("_process_FORALL: call function\n");
    &$func_ref($self,$funcpar,$varsetref);
  }
  # printf("_process_FORALL: end\n") if($debug);
}

1;
