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

use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

sub update_job_per_user_counter {
  my $self = shift;
  
  return();
}

sub get_num_jobs {
  my $self = shift;
  return(scalar keys(%{$self->{JOBINFOREF}}));
}

sub set_options {
  my $self = shift;
  my ($optsref) = @_;
  # print "set_options: ",Dumper($optsref),"\n";

  $self->{LIVE_VIEW_BATCH}=0;
  $self->{LIVE_VIEW_BOOSTER}=0;
  $self->{LIVE_VIEW_GPU}=0;
  $self->{HOMEPAGE}=$optsref->{homepage} if (exists($optsref->{homepage}));
  $self->{SYSTEM_NAME}=$optsref->{system_name} if (exists($optsref->{system_name}));
  $self->{SYSTEM_DESC}=$optsref->{system_desc} if (exists($optsref->{system_desc}));
  $self->{NODES_PER_PLOT}=$optsref->{nodes_per_plot} if (exists($optsref->{nodes_per_plot}));
  $self->{MAXNODES_TO_PLOT}=$optsref->{maxnodes_to_plot} if (exists($optsref->{maxnodes_to_plot}));
  $self->{CNT_MESSAGE}=$optsref->{cnt_message} if (exists($optsref->{cnt_message}));
  $self->{LIVE_VIEW_BATCH}=1 if ($optsref->{live_views}=~/batch/);
  $self->{LIVE_VIEW_BOOSTER}=1 if ($optsref->{live_views}=~/\bbooster\b/);
  $self->{LIVE_VIEW_GPU}=1 if ($optsref->{live_views}=~/\bgpu\b/);
  $self->{DATA_NODEBLOCKSCHEME}=$optsref->{nodeblockscheme} if (exists($optsref->{nodeblockscheme}));
  $self->{DATA_CREATE_ALL_NODEFILES}=$optsref->{create_all_nodefiles} if (exists($optsref->{create_all_nodefiles}));
  
  # print Dumper($self);
  
  return();
}

1;
