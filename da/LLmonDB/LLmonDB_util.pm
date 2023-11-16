# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LLmonDB;

my $VERSION='$Revision: 1.00 $';
my $debug=0;

use strict;
use warnings::unused;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );
use POSIX qw(strftime);

sub get_db_handle {
  my($self) = shift;
  my($db)=@_;
  printf("  LLmonDB: start check_db_open %s\n",$db) if($debug>=3);

  # check if DB is already opened and init
  my $dbobj=undef;
  if( exists($self->{DBOBJS}->{$db}) ) {
    $dbobj=$self->{DBOBJS}->{$db};
  } else {
    my $dbdir=$self->{CONFIGDATA}->{paths}->{dbdir};
    $dbobj=LLmonDB_sqlite->new($dbdir,$db,$self->{VERBOSE});
    $dbobj->init_db();
    $self->{DBOBJS}->{$db}=$dbobj;
    $dbobj->LOGREPORT($dbobj->{DBNAME},"get_db_handle",caller(),"");
  }
  
  return($dbobj);
}

sub close_db {
  my($self) = shift;
  my($db)=@_;
  printf("  LLmonDB: start close_db %s\n",$db) if($debug>=3);
  
  # check if DB is opened, close it
  if( exists($self->{DBOBJS}->{$db}) ) {
    $self->{DBOBJS}->{$db}->LOGREPORT($self->{DBOBJS}->{$db}->{DBNAME},"close_db",caller(),"");
    $self->{DBOBJS}->{$db}->close_db();
    delete($self->{DBOBJS}->{$db});
  }    
  return();
}

sub sec_to_date_week_fn {
  my ($lsec)=@_;
  my($date);
  my @t=localtime($lsec);
  $date=strftime('%Y_w%U',@t);
  return($date);
}

1;