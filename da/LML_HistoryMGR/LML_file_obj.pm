# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LML_file_obj;

my $VERSION='$Revision: 1.00 $';
my($debug)=0;

use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

#use LML_ndtree;

sub new {
  my $self    = {};
  my $proto   = shift;
  my $class   = ref($proto) || $proto;
  my $verbose = shift;
  my $timings = shift;
  $self->{DATA}      = {};
  $self->{VERBOSE}   = $verbose;
  $self->{INSTNAME}  = $0; $self->{INSTNAME}=~s/^.*\///gs; $self->{INSTNAME}="[$self->{INSTNAME}]";
  $self->{TIMINGS}   = $timings; 
  $self->{LASTINFOID} = undef;
  printf("$self->{INSTNAME}\t new %s\n",ref($proto)) if($debug>=3);

  bless $self, $class;
  return $self;
}

# internal data structures:
# $self->{DATA}->                                    # structure corresponds to LML scheme
#                 {OBJECT}->{$id}->{id}    
#                                ->{name}
#                                ->{type}
#                 {INFO}  ->{$oid}->{oid}  
#                                 ->{type}
#                 {INFODATA}->{$oid}->{$key}
#
#                 {TABLELAYOUT}->{$id}->{id}
#                                     ->{gid}
#                                     ->{column}->{$cid}->{cid}
#                                                       ->{key}
#                                                       ->{pos}
#                                                       ->{width}
#                                                       ->{active}
#                 {TABLE}->{$id}->{id}
#                               ->{title}
#                               ->{column}->{$cid}->{id}
#                                                ->{name}
#                                                ->{sort}
#                               ->{row}->{$id}->{cell}->[value,value,...]
#
#                 {NODEDISPLAYLAYOUT}->{$id}->{id}
#                                           ->{gid}
#                                           ->{elements}->[elref, elref, ...]
#                                   ... elref->{elname}  
#                                            ->{key}
#                                            ->{elements}->[elref, elref, ...]
#
#
# derived:
#                 {INFOATTR}->{obj_type}->{$key}  # of occurrences
# 
sub get_data_ref {
  my($self) = shift;
  return($self->{DATA});
} 

sub init_file_obj {
  my($self) = shift;
  $self->{DATA}->{LMLLGUI}={
    'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
    'xmlns:lml' => 'http://eclipse.org/ptp/lml',
    'version' => '1.0',
    'xsi:schemaLocation' => 'http://eclipse.org/ptp/lml lgui.xsd '
  };
  return(1);
} 

sub get_stat {
  my($self) = shift;
  my($log,$type,%types,$id);
  $log="";
  
  {
    my($type,%types,$id);
    $log.=sprintf("objects: total #%d\n",scalar keys(%{$self->{DATA}->{OBJECT}}));
    foreach $id (keys %{$self->{DATA}->{OBJECT}}) {
      $type=$self->{DATA}->{OBJECT}->{$id}->{type};
      $types{$type}++;
    }
    foreach $type (sort keys %types) {
      $log.=sprintf("        |-- %10d (%s)\n",$types{$type},$type);
    }
  }

  {
    my($type,%types,$id);
    if($self->{DATA}->{TABLELAYOUT}) {
      $log.=sprintf("tablelayout: total #%d\n",scalar keys(%{$self->{DATA}->{TABLELAYOUT}}));
      foreach $id (keys %{$self->{DATA}->{TABLELAYOUT}}) {
        $log.=sprintf("        |--        1x%d (%s)\n",
                      scalar keys(%{$self->{DATA}->{TABLELAYOUT}->{$id}->{column}}),
                      $id);
      }
    }
  }

  {
    my($type,%types,$id);
    if($self->{DATA}->{TABLE}) {
      $log.=sprintf("table: total #%d\n",scalar keys(%{$self->{DATA}->{TABLE}}));
      foreach $id (keys %{$self->{DATA}->{TABLE}}) {
        $log.=sprintf("        |--     %4dx%d (%s)\n",
                      scalar keys(%{$self->{DATA}->{TABLE}->{$id}->{row}}),
                      scalar keys(%{$self->{DATA}->{TABLE}->{$id}->{column}}),
                      $id);
      }
    }
  }
  return($log);
} 

sub read_lml_fast {
  my($self) = shift;
  my $infile  = shift;
  my $type    = shift;
  my($xmlin);
  my $rc=0;

  my $tstart=time;
  if(!open(IN,$infile)) {
    print STDERR "$self->{INSTNAME} ERROR: Could not open $infile, leaving...\n";
    return(0);
  }
  while(<IN>) {
    $xmlin.=$_;
  }
  close(IN);
  my $tdiff=time-$tstart;
  printf("$self->{INSTNAME} read XML in %6.4f sec\n",$tdiff) if($self->{VERBOSE});

  $self->{DATA}->{SEARCHTYPE}=$type;
  $tstart=time;

  # light-weight self written xml parser, only working for simple XML files  
  $xmlin=~s/\n/ /gs;
  $xmlin=~s/\s\s+/ /gs;
  my ($tag,$tagname,$rest,$ctag,$nrc);
  foreach $tag (split(/\>\s*/,$xmlin)) {
    $ctag.=$tag;
    $nrc=($ctag=~ tr/\"/\"/);
    if($nrc%2==0) {
      $tag=$ctag;
      $ctag="";
    } else {
      next;
    }
    
    # print "TAG: '$tag'\n";
    if($tag=~/^<[\/\?](.*)[^\s\>]/) {
      $tagname=$1;
      $self->lml_end($self->{DATA},$tagname,());
    } elsif($tag=~/<([^\s]+)\s*$/) {
      $tagname=$1;
      # print "TAG0: '$tagname'\n";
      $self->lml_start($self->{DATA},$tagname,());
    } elsif($tag=~/<([^\s]+)(\s(.*)[^\/])$/) {
      $tagname=$1;
      $rest=$2;$rest=~s/^\s*//gs;$rest=~s/\s*$//gs;
      # print "TAG1: '$tagname' rest='$rest'\n";
      $self->lml_start($self->{DATA},$tagname,split(/=?\"\s*/,$rest));
    } elsif($tag=~/<([^\s]+)(\s(.*)\s?)\/$/) {
      $tagname=$1;
      $rest=$2;$rest=~s/^\s*//gs;$rest=~s/\s*$//gs;
      # print "TAG2: '$tagname' rest='$rest' closed\n";
      $self->lml_start($self->{DATA},$tagname,split(/=?\"\s*/,$rest));
      $self->lml_end($self->{DATA},$tagname,());
    }
  }

  $tdiff=time-$tstart;
  printf("$self->{INSTNAME} read & parse XML in %6.4f sec\n",$tdiff) if($self->{VERBOSE});

  # open(DEB,"> debug");
  # print DEB Dumper($self->{DATA});
  # close(DEB);
  # exit();

  return($rc);

}

# from lib/LLview_parse_xml.pm
sub lml_start {
  my $self=shift; # object reference
  my $o   =shift;
  my $name=shift;
  # print "TMPDEB: >",ref($o),"< >$name<\n";
  my($k,$v,$actnodename,$id,$cid,$oid);

  if($name eq "!--") {
    # a comment
    return(1);
  }
  my %attr=(@_);

  if($name eq "lml:lgui") {
    foreach $k (sort keys %attr) {
      # print "$k: $attr{$k}\n";
      $o->{LMLLGUI}->{$k}=$attr{$k};
    }
    return(1);
  }
  # Objects
  if($name eq "objects") {
    return(1);
  }
  if($name eq "object") {
    $id=$attr{id};
    if(exists($o->{OBJECT}->{$id})) {
      print STDERR "$self->{INSTNAME} WARNING: objects with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      # print "$k: $attr{$k}\n";
      $o->{OBJECT}->{$id}->{$k}=$attr{$k};
    }
    return(1);
  }
  # Information
  if($name eq "information") {
    return(1);
  }
  if($name eq "info") {
    $oid=$attr{oid};
    $o->{LASTINFOID}=$oid;
    $o->{LASTINFOTYPE}=$o->{OBJECT}->{$oid}->{type};
    if(exists($o->{INFO}->{$oid})) {
      print STDERR "$self->{INSTNAME} WARNING info with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      # print "$k: $attr{$k}\n";
      $o->{INFO}->{$oid}->{$k}=$attr{$k};
    }
    return(1);
  }
  if($name eq "data") {
    $id=$o->{LASTINFOID};
    $k=$attr{key};
    $v=$attr{value};
    # $o->{INFOATTR}->{$o->{LASTINFOTYPE}}->{$k}++;
    if(exists($o->{INFODATA}->{$id}->{$k})) {
      print STDERR "$self->{INSTNAME} WARNING: infodata with id >$id< and key >$k< already exists, skipping...\n";
      return(0);
    }
    $o->{INFODATA}->{$id}->{$k}=$v;
    return(1);
  }
  # Tablelayout
  if($name eq "tablelayout") {
    $id=$attr{id};
    $o->{LASTTABLELAYOUTID}=$id;
    if(exists($o->{TABLELAYOUT}->{$id})) {
      print STDERR "$self->{INSTNAME} WARNING: tablelayout with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      # print "$k: $attr{$k}\n";
      $o->{TABLELAYOUT}->{$id}->{$k}=$attr{$k};
    }
    return(1);
  }

  if($name eq "column") {
    $id=$o->{LASTTABLELAYOUTID};
    $cid=$attr{cid};
    $v=$attr{value};

    if(exists($o->{TABLELAYOUT}->{$id}->{column}->{$cid})) {
      print STDERR "$self->{INSTNAME} WARNING: column in tablelayout with id >$cid<  already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      # print "$k: $attr{$k}\n";
      $o->{TABLELAYOUT}->{$id}->{column}->{$cid}->{$k}=$attr{$k};
    }
    return(1);
  }

  # nodedisplaylayout
  if($name eq "nodedisplaylayout") {
    $id=$attr{id};
    if(exists($o->{NODEDISPLAYLAYOUT}->{$id})) {
      print STDERR "$self->{INSTNAME} WARNING: nodedisplaylayout with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      $o->{NODEDISPLAYLAYOUT}->{$id}->{$k}=$attr{$k};
    }
    $o->{NODEDISPLAYLAYOUT}->{$id}->{tree}=LML_ndtree->new("ndlytree");
    $o->{NODEDISPLAYLAYOUT}->{$id}->{tree}->{_level}=-1;
    push(@{$o->{NODEDISPLAYLAYOUTSTACK}},$o->{NODEDISPLAYLAYOUT}->{$id}->{tree});
    return(1);
  }
  if(($name=~/el\d/) || ($name eq 'img')) {
    my $lastelem=$o->{NODEDISPLAYLAYOUTSTACK}->[-1];
    my $treenode=$lastelem->new_child(\%attr,$name);
    push(@{$o->{NODEDISPLAYLAYOUTSTACK}},$treenode);
    return(1);
  }

  print STDERR "$self->{INSTNAME} WARNING: unknown tag >$name< \n";
}

sub lml_end {
  my $self=shift; # object reference
  my $o   =shift;
  my $name=shift;
  if(($name=~/el\d/) || ($name eq 'img')) {
    pop(@{$o->{NODEDISPLAYLAYOUTSTACK}});
  }
}


sub write_lml {
  my($self) = shift;
  my $outfile  = shift;
  my($k,$rc,$id,$c,$key);
  my $tstart=time;
  $rc=1;

  open(OUT,"> $outfile") || die "cannot open file $outfile";
  printf(OUT "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  printf(OUT "<lml:lgui ");
  foreach $k (sort keys %{$self->{DATA}->{LMLLGUI}}) {
    printf(OUT "%s=\"%s\"\n ",$k,$self->{DATA}->{LMLLGUI}->{$k});
  }
  printf(OUT "     \>\n");

  printf(OUT "<objects>\n");
  foreach $id (sort keys %{$self->{DATA}->{OBJECT}}) {
    printf(OUT "<object");
    foreach $k (sort keys %{$self->{DATA}->{OBJECT}->{$id}}) {
      printf(OUT " %s=\"%s\"",$k,$self->{DATA}->{OBJECT}->{$id}->{$k});
    }
    printf(OUT "/>\n");
  }
  printf(OUT "</objects>\n");

  printf(OUT "<information>\n");
  foreach $id (sort keys %{$self->{DATA}->{INFO}}) {
    printf(OUT "<info");
    foreach $k (sort keys %{$self->{DATA}->{INFO}->{$id}}) {
      printf(OUT " %s=\"%s\"",$k,$self->{DATA}->{INFO}->{$id}->{$k});
    }
    printf(OUT ">\n");
    foreach $k (sort keys %{$self->{DATA}->{INFODATA}->{$id}}) {
      printf(OUT "<data key=\"%s\" value=\"%s\"/>\n",$k,$self->{DATA}->{INFODATA}->{$id}->{$k});
    }
    printf(OUT "</info>\n");
  }
  printf(OUT "</information>\n");

  if(exists($self->{DATA}->{TABLE})) {
    foreach $id (sort keys %{$self->{DATA}->{TABLE}}) {
      my $table=$self->{DATA}->{TABLE}->{$id};
      printf(OUT "<table title=\"%s\" id=\"%s\">\n", $table->{title}, $table->{id});
      foreach $k (sort keys %{$table->{column}}) {
        printf(OUT "<column");
        for $key ("id","name","sort") {
          printf(OUT " %s=\"%s\"",$key,  $table->{column}->{$k}->{$key});
        }
        printf(OUT "/>\n");
      }
      foreach $k (sort keys %{$table->{row}}) {
        printf(OUT "<row  %s=\"%s\">\n","oid",$k);
        foreach $c (@{$table->{row}->{$k}->{cell}}) {
          printf(OUT "<cell %s=\"%s\"/>\n","value",$c);
        }
        printf(OUT "</row>\n");
      }
      printf(OUT "</table>\n");
    }
  }

  if(exists($self->{DATA}->{TABLELAYOUT})) {
    foreach $id (sort keys %{$self->{DATA}->{TABLELAYOUT}}) {
      my $tablelayout=$self->{DATA}->{TABLELAYOUT}->{$id};
      printf(OUT "<tablelayout id=\"%s\" gid=\"%s\">\n", $tablelayout->{id}, $tablelayout->{gid});
      foreach $k (sort {$a <=> $b} keys %{$tablelayout->{column}}) {
        printf(OUT "<column");
        for $key ("cid","pos","width","active","key") {
          printf(OUT " %s=\"%s\"",$key,  $tablelayout->{column}->{$k}->{$key});
        }
        printf(OUT "/>\n");
      }
      printf(OUT "</tablelayout>\n");
    }
  }


  if(exists($self->{DATA}->{NODEDISPLAYLAYOUT})) {
    foreach $id (sort keys %{$self->{DATA}->{NODEDISPLAYLAYOUT}}) {
      my $ndlayout=$self->{DATA}->{NODEDISPLAYLAYOUT}->{$id};
      printf(OUT "<nodedisplaylayout id=\"%s\" gid=\"%s\">\n", $ndlayout->{id}, $ndlayout->{gid});
      print OUT $ndlayout->{tree}->get_xml_tree(0);
      printf(OUT "</nodedisplaylayout>\n");
    }
  }

  if(exists($self->{DATA}->{NODEDISPLAY})) {
    foreach $id (sort keys %{$self->{DATA}->{NODEDISPLAY}}) {
      my $nd=$self->{DATA}->{NODEDISPLAY}->{$id};
      printf(OUT "<nodedisplay id=\"%s\" title=\"%s\">\n", $nd->{id}, $nd->{title});
      print OUT "<scheme>\n";
      print OUT $nd->{schemeroot}->get_xml_tree(1);
      print OUT "</scheme>\n";
      print OUT "<data>\n";
      print OUT $nd->{dataroot}->get_xml_tree(1);
      print OUT "</data>\n";
      printf(OUT "</nodedisplay>\n");
    }
  }
  printf(OUT "</lml:lgui>\n");
  close(OUT);

  my $tdiff=time-$tstart;
  printf("$self->{INSTNAME} wrote  XML in %6.4f sec to %s\n",$tdiff,$outfile) if($self->{TIMINGS});
  
  return($rc);
}

1;
