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
use Getopt::Long;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

use LL_jobreport_util;
use LL_jobreport_util_forall;
use LL_jobreport_vars;
use LL_jobreport_dirs;
use LL_jobreport_datasets;
use LL_jobreport_footer;
use LL_jobreport_graphpages;
use LL_jobreport_views;
use LL_convert;

sub new {
  my $self    = {};
  my $proto   = shift;
  my $class   = ref($proto) || $proto;
  my $verbose = shift;
  my $instname = shift;
  my $caller   = shift;
  my $outdir   = shift;
  my $updateconfig = shift;
  my $currentts = shift;
  my $systemname = shift;

  printf("\t LML_jobreport: new %s\n",ref($proto)) if($debug>=3);
  $self->{VERBOSE}   = $verbose; 
  $self->{INSTNAME}  = $0; $self->{INSTNAME}=~s/^.*\///gs; $self->{INSTNAME}="[$self->{INSTNAME}]";
  $self->{INSTNAME}  = $instname if(defined($instname));
  $self->{CALLER}    = $caller; $self->{CALLER}=~s/^.*\/([^\/]+)$/$1/gs;
  $self->{OUTDIR}    = $outdir; 
  $self->{UPDATECONFIG} = 0; # config has changed 
  $self->{UPDATECONFIG} = $updateconfig if(defined($updateconfig)); 

  $self->{JOBINFOREF} = {};
  $self->{RUNNINGJOBS} = {};
  $self->{MAPPING} = {};
  $self->{DIRINFO} = {};
  $self->{IODATA}  = undef;
  $self->{LOADMEMDATA} =  undef;
  $self->{TABLES} =  undef; # hash of defined db->tables

  $self->{CLEANUP_HOURS}=21*24.0; # three weeks
  $self->{DEFERRED_HOURS}=0.50; # 30 min
  # $self->{DEFERRED_HOURS}=4.00; # debug and init


  $self->{LIVE_VIEW_BATCH}=0;
  $self->{LIVE_VIEW_BOOSTER}=0;
  $self->{LIVE_VIEW_GPU}=0;
  $self->{HOMEPAGE}="";
  $self->{SYSTEM_NAME}="system";
  $self->{SYSTEM_NAME} = $systemname if(defined($systemname)); 
  $self->{SYSTEM_DESC}="system desc";
  $self->{NODES_PER_PLOT}=20;
  $self->{MAXNODES_TO_PLOT}=128;
  $self->{CNT_MESSAGE}=0;
  $self->{DATA_NODEBLOCKSCHEME}=1;
  $self->{DATA_CREATE_ALL_NODEFILES}=0;

  $self->{CURRENTTS} = $currentts;
  $self->{DB} = undef;

  $self->{COLOR_WHEEL_NUM_COLORS} = 19;
  $self->{COLOR_WHEEL} = ["BF3F00", "C6541C", "CD6A39", "D47F55", "DB9471",
                          "E3AA8E", "EABFAA", "F1D4C6", "F8EAE3", "FEFEFE",
                          "F7FFF7", "F0FFF0", "E8FFE8", "E0FFE0", "D9FFD9",
                          "D1FFD1", "C9FFC9", "C2FFC2", "BAFFBA"]; 

  # compute Timezone offset (for gnuplot)
  $ENV{LANG}="C";
  my $LOCAL=`date`;
  my $UTC=`date -u -d "$LOCAL" +"%Y-%m-%d %H:%M:%S"`;  #remove timezone reference
  my $UTCSECONDS=`date -d "$UTC" +%s`;
  my $LOCALSECONDS=`date -d "$LOCAL" +%s`;
  $self->{TIMEZONEGAP}=$LOCALSECONDS-$UTCSECONDS;
  # print "$self->{INSTNAME} starting LML_create_jobreports: TZ-gap=$self->{TIMEZONEGAP} seconds\n";

  $self->{LL_CONVERT}=LL_convert->new($self->{VERBOSE},$self->{INSTNAME},$self->{SYSTEM_NAME},$self->{CURRENTTS});
  
  bless $self, $class;
  return $self;
}

sub update_global_vars_in_config {
  my $self = shift;
  my $DB=shift;
  my($outdir,$archdir,$dbdir)=@_;
  my $config_ref=$DB->get_config();
  
  $self->{DB}=$DB;
  
  if(exists($config_ref->{jobreport})) {
    if(exists($config_ref->{jobreport}->{paths})) {
      $config_ref->{jobreport}->{paths}->{dbdir}=$outdir if(defined($dbdir));
      $config_ref->{jobreport}->{paths}->{archdir}=$archdir if(defined($archdir));
      $config_ref->{jobreport}->{paths}->{outputdir}=$outdir if(defined($outdir));
    }
  }
}

sub DESTROY {
  my $self = shift;
}

1;
