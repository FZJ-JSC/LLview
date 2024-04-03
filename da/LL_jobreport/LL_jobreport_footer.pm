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
use JSON;

use lib "$FindBin::RealBin/../lib";
use LML_da_util qw( check_folder );

sub create_footerfiles {
  my $self = shift;
  my $DB=shift;

  my $starttime=time();
  my $config_ref=$DB->get_config();

  # 0: init instantiated variables
  ################################
  my $varsetref;
  $varsetref->{"systemname"}=$self->{SYSTEM_NAME};
  if(exists($config_ref->{jobreport}->{paths})) {
    foreach my $p (keys(%{$config_ref->{jobreport}->{paths}})) {
      $varsetref->{$p}=$config_ref->{jobreport}->{paths}->{$p};
    }
  }

  # scan all footerfiles
  my $fcount=0;
  foreach my $fref (@{$config_ref->{jobreport}->{footerfiles}}) {
    my $fstarttime=time();
    next if(!exists($fref->{footer}));
    my $fname=$fref->{footer}->{name};
    $fcount++;
    $self->process_footer($fname,$fref->{footer},$varsetref);
    printf("%s create_footer:[%02d] footer %-20s    in %7.4fs\n",$self->{INSTNAME}, $fcount,$fname, time()-$fstarttime);
  }
  
  return();
}


sub process_footer {
  my $self = shift;
  my ($fname,$footerref,$varsetref)=@_;
  my ($ds);
  my $file=$self->apply_varset($footerref->{filepath},$varsetref);

  if(0) {
    foreach my $name ("name") {
      $ds->{$name}=$self->apply_varset($footerref->{$name},$varsetref) if(exists($footerref->{$name}));
    }
  }
  if(exists($footerref->{footerset})) {
    foreach my $setref (@{$footerref->{footerset}}) {
      push(@{$ds},$self->process_footersetelem($setref->{footersetelem},$varsetref)) if(exists($setref->{footersetelem}));
    }
  }
  
  # save the JSON file
  my $fh = IO::File->new();
  &check_folder("$file");
  if (!($fh->open("> $file"))) {
    print STDERR "LLmonDB:    WARNING: cannot open $file, skipping...\n";
    return();
  }
  $fh->print($self->encode_JSON($ds));
  $fh->close();
  print "process_view: file=$file ready\n";
}

sub process_footersetelem {
  my $self = shift;
  my ($elemref,$varsetref)=@_;
  my ($ds);

  foreach my $name ("name", "info", "queue") {
    $ds->{$name}=$self->apply_varset($elemref->{$name},$varsetref) if(exists($elemref->{$name}));
  }
  if(exists($elemref->{'show_pattern'})) {
    foreach my $key (keys(%{$elemref->{'show_pattern'}})) {
      $ds->{'show_pattern'}->{$key}=$elemref->{'show_pattern'}->{$key};
    }
  }
  if(exists($elemref->{graphs})) {
    foreach my $graphref (@{$elemref->{graphs}}) {
      push(@{$ds->{graphs}},$self->process_footersetelemgraph($graphref->{graph},$varsetref)) if(exists($graphref->{graph}));
    }
  }
  return($ds);
}

sub process_footersetelemgraph {
  my $self = shift;
  my($graphref,$varsetref)=@_;
  my ($ds);

  # print Dumper($graphref);

  # foreach my $name ("name", "xcol", "datapath") {
  foreach my $name (keys(%{$graphref})) {
    next if ($name eq "traces"); # To skip the traces key (that is parsed below)
    $ds->{$name}=$self->apply_varset($graphref->{$name},$varsetref) if(exists($graphref->{$name}));
  }

  # $ds->{layout}=$graphref->{layout};
  
  if(exists($graphref->{traces})) {
    foreach my $traceref (@{$graphref->{traces}}) {
      push(@{$ds->{traces}},$self->process_footersettrace($traceref->{trace},$varsetref)) if(exists($traceref->{trace}));
    }
  }

  return($ds);
}

sub process_footersettrace {
  my $self = shift;
  my ($traceref,$varsetref)=@_;
  my ($ds);

  # Parse all keys for plotly graphs
  foreach my $name (keys(%{$traceref})) {
    $ds->{$name}=$self->apply_varset($traceref->{$name},$varsetref) if(exists($traceref->{$name}));
  }

  foreach my $name ("marker") {
    $ds->{$name}=$traceref->{$name} if(exists($traceref->{$name}));
  }

  return($ds);
}

1;
