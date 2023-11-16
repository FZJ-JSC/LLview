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

sub create_views {
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

  # scan all views
  my $vcount=0;
  foreach my $vref (@{$config_ref->{jobreport}->{views}}) {
    my $vstarttime=time();
    next if(!exists($vref->{view}));
    next if(!exists($vref->{view}->{name}));
    next if(!exists($vref->{view}->{filepath}));
    my $vname=$vref->{view}->{name};
    $vcount++;
    # print Dumper($vref);
    $self->process_view($vname,$vref->{view},$varsetref);
    printf("%s create_views:[%02d] view %-20s    in %7.4fs\n",$self->{INSTNAME}, $vcount,$vname, time()-$vstarttime);
  }
  
  return();
}

sub process_view {
  my $self = shift;
  my ($vname,$viewref,$varsetref)=@_;
  my ($ds);
  my $file=$self->apply_varset($viewref->{filepath},$varsetref);

  foreach my $name ("title","image","home","logo","info","search_field") {
    $ds->{$name}=$self->apply_varset($viewref->{$name},$varsetref) if(exists($viewref->{$name}));
  }
  if(exists($viewref->{data})) {
    foreach my $name ("system","permission","view") {
      $ds->{data}->{$name}=$self->apply_varset($viewref->{data}->{$name},$varsetref) if(exists($viewref->{data}->{$name}));
    }
  }

  if(exists($viewref->{pages})) {
    foreach my $pref (@{$viewref->{pages}}) {
      push(@{$ds->{pages}},$self->process_view_page($pref->{page},$varsetref)) if(exists($pref->{page}));
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
  # print "process_view: file=$file ready\n";

}

sub process_view_page {
  my $self = shift;
  my ($pageref,$varsetref)=@_;
  my ($ds);

  foreach my $name ("name", "section", "icon", "context", "href", "default", "template", "footer_template", "footer_graph_config", "graph_page_config") {
    $ds->{$name}=$self->apply_varset($pageref->{$name},$varsetref) if(exists($pageref->{$name}));
  }
  
  if(exists($pageref->{ref})) {
    foreach my $ref (@{$pageref->{ref}}) {
      push(@{$ds->{ref}},$ref);
    }
  }
  if(exists($pageref->{data})) {
    if(exists($pageref->{data}->{default_columns})) {
      foreach my $ref (@{$pageref->{data}->{default_columns}}) {
        push(@{$ds->{data}->{default_columns}},$ref);
      }
    }
    if(exists($pageref->{data}->{view})) {
      $ds->{data}->{view}=$pageref->{data}->{view};
    }
  }
  if(exists($pageref->{functions})) {
    foreach my $ref (@{$pageref->{functions}}) {
      push(@{$ds->{functions}},$ref);
    }
  }
  if(exists($pageref->{scripts})) {
    foreach my $ref (@{$pageref->{scripts}}) {
      push(@{$ds->{scripts}},$ref);
    }
  }

  if(exists($pageref->{pages})) {
    foreach my $pref (@{$pageref->{pages}}) {
      push(@{$ds->{pages}},$self->process_view_page($pref->{page},$varsetref)) if(exists($pref->{page}));
    }
  }
  return($ds);
}

1;
