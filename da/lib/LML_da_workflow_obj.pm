# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 
#    Filipe Guimarães (Forschungszentrum Juelich GmbH) 

package LML_da_workflow_obj;

my $debug=0;

use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

sub new {
  my $self    = {};
  my $proto   = shift;
  my $class   = ref($proto) || $proto;
  my $verbose = shift;
  my $timings = shift;
  printf("\t LML_da_workflow_obj: new %s\n",ref($proto)) if($debug>=3);
  $self->{DATA}      = {};
  $self->{VERBOSE}   = $verbose; 
  $self->{TIMINGS}   = $timings; 
  $self->{LASTINFOID} = undef;
  bless $self, $class;
  return $self;
}

sub read_xml_fast {
  my($self) = shift;
  my $infile  = shift;
  my($xmlin);
  my $rc=0;

  my $tstart=time;
  if(!open(IN,$infile)) {
    print STDERR "$0: ERROR: could not open $infile, leaving...\n";return(0);
  }
  while(<IN>) {
    $xmlin.=$_;
  }
  close(IN);
  my $tdiff=time-$tstart;
  printf("LML_da_workflow_obj: read  XML in %6.4f sec\n",$tdiff) if($self->{VERBOSE});

  if(!$xmlin) {
    print STDERR "$0: ERROR: empty file $infile, leaving...\n";return(0);
  }

  $tstart=time;

  # light-weight self written xml parser, only working for simple XML files  
  $xmlin=~s/\n/ /gs;
  $xmlin=~s/\s\s+/ /gs;
  my ($tag,$tagname,$rest,$ctag,$nrc,@list);
  foreach $tag (split(/\>\s*/,$xmlin)) {
    $ctag.=$tag;
    $nrc=($ctag=~ tr/\"/\"/);
    if($nrc%2==0) {
      $tag=$ctag;
      $ctag="";
    } else {
      next;
    }
    
    # print STDERR "TAG: '$tag'\n";
    if($tag=~/^<[\/\?](.*[^\s\>])/) { # end of a tag
      $tagname=$1;
      # print "TAGE: '$tagname'\n";
      $self->xml_end($self->{DATA},$tagname,());
    } elsif($tag=~/<([^\s]+)\s*$/) { # start of simple tag
      $tagname=$1;
      # print STDERR "TAG0: '$tagname'\n";
      $self->xml_start($self->{DATA},$tagname,());
    } elsif($tag=~/<([^\s]+)(\s(.*)[^\/])$/) { # start of tag with options
      $tagname=$1;
      $rest=$2;$rest=~s/^\s*//gs;$rest=~s/\s*$//gs;$rest=~s/\=\s+\"/\=\"/gs;
      # print STDERR "TAG1: '$tagname' rest='$rest'\n";
      @list = $rest =~ /([^\s]+?)="(.*?)"/g;
      $self->xml_start($self->{DATA},$tagname,@list);
    } elsif($tag=~/<([^\s]+)(\s(.*)\s?)\/$/) { # closed tag (that closes by itself, <.../>) with options
      $tagname=$1;
      $rest=$2;$rest=~s/^\s*//gs;$rest=~s/\s*$//gs;$rest=~s/\=\s+\"/\=\"/gs;
      # print STDERR "TAG2: '$tagname' rest='$rest' closed\n";
      @list = $rest =~ /([^\s]+?)="(.*?)"/g;
      $self->xml_start($self->{DATA},$tagname,@list);
      $self->xml_end($self->{DATA},$tagname,());
    }
  }

  $tdiff=time-$tstart;
  printf("LML_da_workflow_obj: parse XML in %6.4f sec\n",$tdiff) if($self->{VERBOSE});

  # print Dumper($self->{DATA});
  return($rc);
}


sub xml_start {
  my $self=shift; # object reference
  my $o   =shift;
  my $name=shift;
  my($k,$v,$actnodename,$id,$sid,$oid);

  # print "LML_da_workflow_obj: lml_start >$name< \n";

  if($name eq "!--") {
    # skipping comment
    return(1);
  }
  my %attr=(@_);
  # Substituting environment variables on values
  foreach $k (sort keys %attr) {
    while ( $attr{$k} =~ /\$\{(\w+)\}/ ) {
      # Checking if environment variable is defined
      if (defined($ENV{$1})) {
        $attr{$k} =~ s/\$\{(\w+)\}/$ENV{$1}/g;
        $attr{$k} =~ s/\$ENV\{(\w+)\}/$ENV{$1}/g;
      } else {
        $attr{$k} =~ s/\$\{(\w+)\}//g;
        $attr{$k} =~ s/\$ENV\{(\w+)\}//g;
      }
    }
  }

  if($name eq "LML_da_workflow") {
    foreach $k (sort keys %attr) {
      $o->{LML_da_workflow}->{$k}=$attr{$k};
    }
    return(1);
  }

  if($name eq "vardefs") {
    return(1);
  }
  if($name eq "var") {
    push(@{$o->{vardefs}->[0]->{var}},\%attr);
    return(1);
  }
  if($name eq "step") {
    $id=$attr{id};
    $o->{LASTSTEPID}=$id;
    foreach $k (sort keys %attr) {
      $o->{step}->{$id}->{$k}=$attr{$k};
    }
    return(1);
  }
  if($name eq "cmd") {
    $id=$attr{id};
    $sid=$o->{LASTSTEPID};

    push(@{$o->{step}->{$sid}->{cmd}},\%attr);

    return(1);
  }

  # unknown element
  print "LML_da_workflow_obj: WARNING unknown tag >$name< \n";
}

sub xml_end {
  my $self=shift; # object reference
  my $o   =shift;
  my $name=shift;
  # print "LML_da_workflow_obj: lml_end >$name< \n";

  if($name=~/vardefs/) {
  }
  if($name=~/step/) {
    $o->{LASTSTEPID}=undef;
  }

#    print Dumper($o->{NODEDISPLAYSTACK});
}


sub write_xml {
  my($self) = shift;
  my($k,$rc,$id,$c,$key,$ref);
  my $outfile  = shift;
  my $tstart=time;
  my $data="";

  $rc=1;

  open(OUT,"> $outfile") || die "cannot open file $outfile";

  printf(OUT "<LML_da_workflow ");
  foreach $k (sort keys %{$self->{DATA}->{LML_da_workflow}}) {
    printf(OUT "%s=\"%s\"\n ",$k,$self->{DATA}->{LMLLGUI}->{$k});
  }
  printf(OUT "     \>\n");

  printf(OUT "<vardefs>\n");
  foreach $ref (@{$self->{DATA}->{vardefs}->[0]->{var}}) {
    printf(OUT "<var");
    foreach $k (sort keys %{$ref}) {
      printf(OUT " %s=\"%s\"",$k,$ref->{$k});
    }
    printf(OUT "/>\n");
  }
  printf(OUT "</vardefs>\n");

  foreach $id (sort keys %{$self->{DATA}->{step}}) {
    printf(OUT "<step");
    foreach $k (sort keys %{$self->{DATA}->{step}->{$id}}) {
      next if($k eq "cmd");
      printf(OUT " %s=\"%s\"",$k,$self->{DATA}->{step}->{$id}->{$k});
    }
    printf(OUT ">\n");
    if(exists($self->{DATA}->{step}->{$id}->{cmd})) {
      foreach $ref (@{$self->{DATA}->{step}->{$id}->{cmd}}) {
        printf(OUT "<cmd ");
        foreach $k (sort keys %{$ref}) {
          printf(OUT " %s=\"%s\"",$k,$ref->{$k});
        }
        printf(OUT "/>\n");
      }
    }
    printf(OUT "</step>\n");
  }
  
  printf(OUT "</LML_da_workflow>\n");
  
  close(OUT);

  my $tdiff=time-$tstart;
  printf("LML_da_workflow_obj: wrote  XML in %6.4f sec to %s\n",$tdiff,$outfile) if($self->{TIMINGS});
  
  return($rc);
}

1;
