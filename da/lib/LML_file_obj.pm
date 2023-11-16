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

my $debug=0;

use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

use LML_ndtree;
use LML_da_util;

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
  printf(STDERR "$self->{INSTNAME}\t new %s\n",ref($proto)) if($debug>=3);

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
#                 {REQUEST}->{attr}->{$key}
#                          ->{driver}->{attr}->{name}
#                                    ->{command}->{$name}->{exec}
#                                                        ->{input}
#                          ->{layoutManagement}->{attr}->{$key}              
#
#                 {TABLELAYOUT}->{$id}->{id}
#                                     ->{gid}
#                                     ->{column}->{$cid}->{cid}
#                                                       ->{key}
#                                                       ->{pos}
#                                                       ->{width}
#                                                       ->{active}
#														->{pattern}=[ [include, regexp]|
#                                                               [exclude, regexp]|                
#                                                               [select,rel,value]  ...]
#                 {TABLE}->{$id}->{id}
#                               ->{title}
#                               ->{column}->{$cid}->{id}
#                                                 ->{name}
#                                                 ->{sort}
#                                                 
#                               ->{row}->{$id}->{cell}->{$cid}->{value}
#                                                             ->{cid}
#
#                 {NODEDISPLAYLAYOUT}->{$id}->{id}
#                                           ->{gid}
#                                           ->{elements}->[elref, elref, ...]
#                                   ... elref->{elname}  
#                                            ->{key}
#                                            ->{elements}->[elref, elref, ...]
#
#                 {NODEDISPLAY}->{$id}->{id}
#                                            ->{elements}->[elref, elref, ...]
#                                               ... elref->{elname}  
#                                                        ->{key}
#                                                        ->{elements}->[elref, elref, ...]
#                 {SPLITLAYOUT}->{$id}->{id}
#                                     ->{elements}->[elref, elref, ...]
#                                       ... elref->{elname}  
#                                                ->{key}
#                                                ->{elements}->[elref, elref, ...]
#
#                 {CHART}->{$id}->{id}
#                               ->{title}
#                               ->{axes}->{x|y}->{type}
#                                              ->{dist}
#                                              ->{unit}
#                                              ->{label}
#                                              ->{min}
#                                              ->{max}
#                                              ->{ticcount}
#                                              ->{ticlabels}->{pos}->[...]
#                                                           ->{text}->[...]
#                                ->{data}->{name}->{name}
#                                                ->{descriptions}
#                                                ->{count}
#                                                ->{p}->{x}->[...]
#                                                ->{p}->{y}->[...]
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
    'version' => '1.1',
    'xsi:schemaLocation' => 'http://eclipse.org/ptp/lml http://eclipse.org/ptp/schemas/v1.1/lgui.xsd'
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
      $types{$type}++ if($type);
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

  {
    my($type,%types,$id);
    if($self->{DATA}->{NODEDISPLAYLAYOUT}) {
      $log.=sprintf("nodedisplaylayout: total #%d\n",scalar keys(%{$self->{DATA}->{NODEDISPLAYLAYOUT}}));
    }
  }

  {
    my($type,%types,$id);
    if($self->{DATA}->{NODEDISPLAY}) {
      $log.=sprintf("nodedisplay: total #%d\n",scalar keys(%{$self->{DATA}->{NODEDISPLAY}}));
    }
  }

  {
    my($type,%types,$id);
    if($self->{DATA}->{SPLITLAYOUT}) {
      $log.=sprintf("splitlayout: total #%d\n",scalar keys(%{$self->{DATA}->{SPLITLAYOUT}}));
    }
  }

  return($log);
} 


sub read_rawlml_fast {
  my($self) = shift;
  my $infile  = shift;
  my($xmlin,$line,$pair);
  my $rc=0;

  my $tstart=time;
  if(!open(IN,$infile)) {
    print STDERR "$self->{INSTNAME} ERROR: Could not open $infile, leaving...\n";
    return(0);
  }

  # add new header, because read_rawlml_fast will skip this
  $self->init_file_obj();

  # skip to objects section
  while($line=<IN>) {
    last if($line=~/<objects>/);
  }
  # read objects 
  while($line=<IN>) {
    last if($line=~/<\/objects>/);
    if($line=~/<object\s+(.*)\/>/) {
      my $newobj;
      # print "--> object: $1\n";
      foreach $pair (split(/\s/,$1)) {
        $pair=~/^(.*)=\"(.*)\"/;
        $newobj->{$1}=$2;
      }
      $self->{DATA}->{OBJECT}->{$newobj->{id}}=$newobj if(exists($newobj->{id}));
    }
  }

  # skip to information section
  while($line=<IN>) {
    last if($line=~/<information>/);
    print "skip $line";
  }
  # read information
  while($line=<IN>) {
    last if($line=~/<\/information>/);

    if($line=~/<info\s+(.*)>/) {
      # print "found info($1)\n";
      my $newobj;
      foreach $pair (split(/\s/,$1)) {
        $pair=~/^(.*)=\"(.*)\"/;
        $newobj->{$1}=$2;
      }
      $self->{DATA}->{INFO}->{$newobj->{oid}}=$newobj if(exists($newobj->{oid}));
      # read data
      while($line=<IN>) {
        last if($line=~/<\/info>/);
        if($line=~/<data\s+key=\"(.*)\"\s+value=\"(.*)\"\/>/) {
          $self->{DATA}->{INFODATA}->{$newobj->{oid}}->{$1}=$2 if(exists($newobj->{oid}));
        }
      }
    }
  }

  close(IN);
  my $tdiff=time-$tstart;
  printf("$self->{INSTNAME} read & parse XML in %6.4f sec\n",$tdiff) if($self->{VERBOSE});

  # open(DEB,"> debug");
  # print DEB Dumper($self->{DATA});
  # close(DEB);
  # exit();

  return($rc);
}

sub read_lml_fast {
  my($self) = shift;
  my $infile = shift;
  my($xmlin);
  my $rc=0;

  my $tstart=time;

  if($infile=~/.gz$/) {
    if(!open(IN,"zcat $infile|")) {
      print STDERR "$self->{INSTNAME} ERROR: Could not open $infile, leaving...\n";
      return(0);
    }
  } else {
    if(!open(IN,$infile)) {
      print STDERR "$self->{INSTNAME} ERROR: Could not open $infile, leaving...\n";
      return(0);
    }
  }
  
  while(<IN>) {
    $xmlin.=$_;
  }
  close(IN);
  my $tdiff=time-$tstart;
  printf(STDERR "$self->{INSTNAME} read XML in %6.4f sec\n",$tdiff) if($self->{VERBOSE});

  if(!$xmlin) {
    print STDERR "$self->{INSTNAME} ERROR: empty file $infile, leaving...\n";
    return(0);
  }

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
      $ctag.="\>";
      next;
    }

    # comment
    next if($tag =~ /\!\-\-/);

    # print "TAG: '$tag'\n";
    if($tag=~/^<[\/\?](.*[^\s\>])/) {
      $tagname=$1;
      # print "TAGE: '$tagname'\n";
      $self->lml_end($self->{DATA},$tagname,());
    } elsif($tag=~/<([^\s\/]+)\s*$/) {
      $tagname=$1;
      # print "TAG0: '$tagname'\n";
      $self->lml_start($self->{DATA},$tagname,());
    } elsif($tag=~/<([^\s]+)(\s(.*)[^\/])$/) {
      $tagname=$1;
      $rest=$2;$rest=~s/^\s*//gs;$rest=~s/\s*$//gs;$rest=~s/\=\s+\"/\=\"/gs;$rest=~s/\s+\=\"/\=\"/gs;$rest=~s/""/"-LML-"/gs;
      $rest=&LML_da_util::escape_special_characters($rest) if($tagname=~/(select)/);
      # print "TAG1: '$tagname' rest='$rest'\n";
      $self->lml_start($self->{DATA},$tagname,split(/=?\"\s*/,$rest));
    } elsif($tag=~/<([^\s\/]+)(\s(.*)\s?)\/$/) {
      $tagname=$1;
      $rest=$2;$rest=~s/^\s*//gs;$rest=~s/\s*$//gs;$rest=~s/\=\s+\"/\=\"/gs;$rest=~s/\s+\=\"/\=\"/gs;$rest=~s/""/"-LML-"/gs;
      # print "TAG2: '$tagname' rest='$rest' closed\n";
      $rest=&LML_da_util::escape_special_characters($rest) if($tagname=~/(select)/);
      $self->lml_start($self->{DATA},$tagname,split(/=?\"\s*/,$rest));
      $self->lml_end($self->{DATA},$tagname,());
    } elsif($tag=~/<([^\s\/]+)\/$/) {
      $tagname=$1;
      $rest="";
      # print "TAG2e: '$tagname' rest='$rest' closed\n";
      $self->lml_start($self->{DATA},$tagname,split(/=?\"\s*/,$rest));
      $self->lml_end($self->{DATA},$tagname,());
    }
  }

  $tdiff=time-$tstart;
  printf(STDERR "$self->{INSTNAME} parse XML in %6.4f sec\n",$tdiff) if($self->{VERBOSE});

  # print Dumper($self->{DATA});
  return($rc);

}

sub lml_start {
  my $self=shift; # object reference
  my $o   =shift;
  my $name=shift;
  my($k,$v,$actnodename,$id,$cid,$oid);

  if($name eq "!--") {
    # a comment
    return(1);
  }
  my %attr=(@_);

#   print "$self->{INSTNAME} lml_start >$name< ",Dumper(\%attr),"\n";

  foreach $k (sort keys %attr) {
    $attr{$k}=~s/-LML-//gs;
  }

  if($name =~ /(.*):layout/) {
    foreach $k (sort keys %attr) {
      $o->{LMLLGUI}->{$k}=$attr{$k};
    }
    return(1);
  }

  if($name eq "lml:lgui") {
    foreach $k (sort keys %attr) {
      $o->{LMLLGUI}->{$k}=$attr{$k};
    }
    return(1);
  }

  if($name =~/(.*):lgui/) {
    foreach $k (sort keys %attr) {
      $o->{LMLLGUI}->{$k}=$attr{$k};
    }
  }

  if($name eq "ns2:lguiType") {
    foreach $k (sort keys %attr) {
      $o->{LMLLGUI}->{$k}=$attr{$k};
    }
    return(1);
  }

  if($name eq "ns2:lgui") {
    foreach $k (sort keys %attr) {
      $o->{LMLLGUI}->{$k}=$attr{$k};
    }
    return(1);
  }


# general tags, used in more than one tags
###########################################################################################
  if($name eq "data") {
    if($o->{LASTINFOID}) {
      $id=$o->{LASTINFOID};
      $k=$attr{key};
      $v=$attr{value};
      if(exists($o->{INFODATA}->{$id}->{$k})) {
        print STDERR "$self->{INSTNAME} WARNING: infodata with id >$id< and key >$k< already exists, skipping...\n";
        return(0);
      }
      $o->{INFODATA}->{$id}->{$k}=$v;
      return(1);
    }
    if($o->{LASTNODEDISPLAYID}) {
      $id=$o->{LASTNODEDISPLAYID};
      $o->{NODEDISPLAY}->{$id}->{dataroot}=LML_ndtree->new("dataroot");
      $o->{NODEDISPLAY}->{$id}->{dataroot}->{_level}=-1;
      push(@{$o->{NODEDISPLAYSTACK}},$o->{NODEDISPLAY}->{$id}->{dataroot});
    }
    if($o->{LASTCHARTID}) {
      $id=$o->{LASTCHARTID};
      if(exists($attr{name})) {
        $o->{LASTCHARTDATANAME}=$attr{name};
        $o->{CHART}->{$id}->{data}->{$attr{name}}->{name}=$attr{name};
      }
    }
    return(1);
  }

# handling request tags
###########################################################################################
  if($name eq "request") {
    foreach $k (sort keys %attr) {
      $o->{REQUEST}->{attr}->{$k}=$attr{$k};
    }
    return(1);
  }
  if($name eq "layoutManagement") {
    foreach $k (sort keys %attr) {
      $o->{REQUEST}->{layoutManagement}->{attr}->{$k}=$attr{$k};
    }
    return(1);
  }
  if($name eq "driver") {
    foreach $k (sort keys %attr) {
      $o->{REQUEST}->{driver}->{attr}->{$k}=$attr{$k};
    }
    return(1);
  }
  if($name eq "command") {
    if(exists($attr{name})) {
      my $cmdname=$attr{name};
      foreach $k (sort keys %attr) {
        $o->{REQUEST}->{driver}->{command}->{$cmdname}->{$k}=$attr{$k};
      }
    }
    return(1);
  }

# handling objects tags
###########################################################################################
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
      $o->{OBJECT}->{$id}->{$k}=$attr{$k};
    }
    return(1);
  }

# handling information tags
###########################################################################################
  if($name eq "information") {
    return(1);
  }
  if($name eq "info") {
    $oid=$attr{oid};
    $o->{LASTINFOID}=$oid;
    $o->{LASTINFOTYPE}=$o->{OBJECT}->{$oid}->{type};
    if(exists($o->{INFO}->{$oid})) {
      print STDERR "$self->{INSTNAME} WARNING: info with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      # print "$k: $attr{$k}\n";
      $o->{INFO}->{$oid}->{$k}=$attr{$k};
    }
    return(1);
  }

# handling tables
###########################################################################################
  if($name eq "table") {
    $id=$attr{id};
    $o->{LASTTABLEID}=$id;
    if(exists($o->{TABLE}->{$id})) {
      print STDERR "$self->{INSTNAME} WARNING: Table with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      $o->{TABLE}->{$id}->{$k}=$attr{$k};
    }
    return(1);
  }
  if($name eq "tablelayout") {
    $id=$attr{id};
    $o->{LASTTABLELAYOUTID}=$id;
    if(exists($o->{TABLELAYOUT}->{$id})) {
      print STDERR "$self->{INSTNAME} WARNING: Tablelayout with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      $o->{TABLELAYOUT}->{$id}->{$k}=$attr{$k};
    }
    return(1);
  }
  if($name eq "column") {
    if($o->{LASTTABLEID}) {
      $id=$o->{LASTTABLEID};
      $cid=$attr{id};
      $o->{LASTCOLUMNID}=$cid;
      $v=$attr{value};
      if(exists($o->{TABLE}->{$id}->{column}->{$cid})) {
        print STDERR "$self->{INSTNAME} WARNING: column in table with id >$cid<  already exists, skipping...\n";
        return(0);
      }
      foreach $k (sort keys %attr) {
        $o->{TABLE}->{$id}->{column}->{$cid}->{$k}=$attr{$k};
      }
    }
    if($o->{LASTTABLELAYOUTID}) {
      $id=$o->{LASTTABLELAYOUTID};
      $cid=$attr{cid};
      $o->{LASTCOLUMNID}=$cid;
      $v=$attr{value};
      if(exists($o->{TABLELAYOUT}->{$id}->{column}->{$cid})) {
        print STDERR "$self->{INSTNAME} WARNING: column in tablelayout with id >$cid<  already exists, skipping...\n";
        return(0);
      }
      foreach $k (sort keys %attr) {
        $o->{TABLELAYOUT}->{$id}->{column}->{$cid}->{$k}=$attr{$k};
      }
    }
    return(1);
  }
  if($name eq "pattern") {
    if($o->{LASTTABLELAYOUTID}) {
      $id=$o->{LASTTABLELAYOUTID};
      if($o->{LASTCOLUMNID}) {
        $cid=$o->{LASTCOLUMNID};
        $o->{LASTPATTERNLIST}=$o->{TABLELAYOUT}->{$id}->{column}->{$cid}->{pattern}=[];
      }
    }
    return(1);
  }
  if($name eq "exclude") {
    if($o->{LASTPATTERNLIST}) {
      if(exists($attr{'regexp'})) {
        push(@{$o->{LASTPATTERNLIST}},['exclude',$attr{'regexp'}]);
      }
    }
    return(1);
  }
  if($name eq "include") {
    if($o->{LASTPATTERNLIST}) {
      if(exists($attr{'regexp'})) {
        push(@{$o->{LASTPATTERNLIST}},['include',$attr{'regexp'}]);
      }
    }
    return(1);
  }
  if($name eq "select") {
    if($o->{LASTPATTERNLIST}) {
      if(exists($attr{'rel'}) && (exists($attr{'value'}))) {
        push(@{$o->{LASTPATTERNLIST}},['select',$attr{'rel'},$attr{'value'}]);
      }
    }
    return(1);
  }

# handling nodedisplays
###########################################################################################
  if($name eq "nodedisplay") {
    $id=$attr{id};
    $o->{LASTNODEDISPLAYID}=$id;
    if(exists($o->{NODEDISPLAY}->{$id})) {
      print STDERR "$self->{INSTNAME} WARNING: nodedisplay with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      $o->{NODEDISPLAY}->{$id}->{$k}=$attr{$k};
    }
    return(1);
  }
  if($name eq "nodedisplaylayout") {
    $id=$attr{id};
    $o->{LASTNODEDISPLAYLAYOUTID}=$id;
    if(exists($o->{NODEDISPLAYLAYOUT}->{$id})) {
      print STDERR "$self->{INSTNAME} WARNING: nodedisplaylayout with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      $o->{NODEDISPLAYLAYOUT}->{$id}->{$k}=$attr{$k};
    }
    $o->{NODEDISPLAYLAYOUT}->{$id}->{tree}=LML_ndtree->new("ndlytree");
    $o->{NODEDISPLAYLAYOUT}->{$id}->{tree}->{_level}=-1;
    push(@{$o->{NODEDISPLAYSTACK}},$o->{NODEDISPLAYLAYOUT}->{$id}->{tree});
    return(1);
  }
  if($name eq "scheme") {
    if($o->{LASTNODEDISPLAYID}) {
      $id=$o->{LASTNODEDISPLAYID};
      $o->{NODEDISPLAY}->{$id}->{schemeroot}=LML_ndtree->new("schemeroot");
      $o->{NODEDISPLAY}->{$id}->{schemeroot}->{_level}=-1;
      push(@{$o->{NODEDISPLAYSTACK}},$o->{NODEDISPLAY}->{$id}->{schemeroot});
    }
    return(1);
  }
  #Read scheme hint within nodedisplaylayout
  if($name eq "schemehint") {
    if($o->{LASTNODEDISPLAYLAYOUTID}) {
      $id=$o->{LASTNODEDISPLAYLAYOUTID};
      $o->{NODEDISPLAYLAYOUT}->{$id}->{schemehint}=LML_ndtree->new("schemeroot");
      $o->{NODEDISPLAYLAYOUT}->{$id}->{schemehint}->{_level}=-1;
      push(@{$o->{NODEDISPLAYSTACK}},$o->{NODEDISPLAYLAYOUT}->{$id}->{schemehint});
    }
    return(1);
  }
  if(($name=~/el\d/) || ($name eq 'img') ) {
    my $lastelem=$o->{NODEDISPLAYSTACK}->[-1];
    my $treenode=$lastelem->new_child(\%attr,$name);
    push(@{$o->{NODEDISPLAYSTACK}},$treenode);
    return(1);
  }

# handling splitlayout (needed at least for java appl.)
###########################################################################################
  if($name eq "splitlayout") {
    $id=$attr{id};
    $o->{LASTSPLITLAYOUTID}=$id;
    if(exists($o->{SPLITLAYOUT}->{$id})) {
      print STDERR "$self->{INSTNAME} WARNING: splitlayout with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      $o->{SPLITLAYOUT}->{$id}->{$k}=$attr{$k};
    }
    $o->{SPLITLAYOUT}->{$id}->{tree}=LML_ndtree->new("splitlayout");
    $o->{SPLITLAYOUT}->{$id}->{tree}->{_level}=-1;
    push(@{$o->{SPLITLAYOUTSTACK}},$o->{SPLITLAYOUT}->{$id}->{tree});
    return(1);
  }
  if(($name=~/top/) || ($name eq 'bottom') || ($name=~/left/) || ($name eq 'right') ) {
    my $lastelem=$o->{SPLITLAYOUTSTACK}->[-1];
    my $treenode=$lastelem->new_child(\%attr,$name);
    push(@{$o->{SPLITLAYOUTSTACK}},$treenode);
    return(1);
  }

# handling tables
###########################################################################################
  if($name eq "chart") {
    $id=$attr{id};
    $o->{LASTCHARTID}=$id;
    if(exists($o->{CHART}->{$id})) {
      print STDERR "$self->{INSTNAME} WARNING: chart with id >$id< already exists, skipping...\n";
      return(0);
    }
    foreach $k (sort keys %attr) {
      $o->{CHART}->{$id}->{$k}=$attr{$k};
    }
    return(1);
  }
  if($name eq "axes") {
    return(1);
  }
  if (($name eq "x") || ($name eq "y") ) {
    if($o->{LASTCHARTID}) {
      $id=$o->{LASTCHARTID};
      $cid=$name;
      $o->{LASTAXESID}=$cid;
      if(exists($o->{CHART}->{$id}->{axes}->{$cid})) {
        print STDERR "$self->{INSTNAME} WARNING: axes in chart with id >$cid<  already exists, skipping...\n";
        return(0);
      }
      foreach $k (sort keys %attr) {
        $o->{CHART}->{$id}->{axes}->{$cid}->{$k}=$attr{$k};
      }
    }
    return(1);
  }
  if($name eq "ticlabels") {
    return(1);
  }
  if($name eq "label") {
    if($o->{LASTCHARTID}) {
      $id=$o->{LASTCHARTID};
      if($o->{LASTAXESID}) {
        $cid=$o->{LASTAXESID};
        if( exists($attr{'pos'}) && exists($attr{'text'}) ) {
          push(@{$o->{CHART}->{$id}->{axes}->{$cid}->{ticlabels}->{pos}},$attr{'pos'});
          push(@{$o->{CHART}->{$id}->{axes}->{$cid}->{ticlabels}->{text}},$attr{'text'});
          $o->{CHART}->{$id}->{axes}->{$cid}->{ticcount}++;
        }
      }
    }
    return(1);
  }
  if($name eq "p") {
    if($o->{LASTCHARTID}) {
      $id=$o->{LASTCHARTID};
      if($o->{LASTCHARTDATANAME}) {
        $cid=$o->{LASTCHARTDATANAME};
        if( exists($attr{'x'}) && exists($attr{'y'}) ) {
          push(@{$o->{CHART}->{$id}->{data}->{$cid}->{p}->{x}},$attr{'x'});
          push(@{$o->{CHART}->{$id}->{data}->{$cid}->{p}->{y}},$attr{'y'});
          $o->{CHART}->{$id}->{data}->{$cid}->{count}++;
        }
      }
    }
    return(1);
  }

  
  
# handling unused / not needed tags
###########################################################################################
  if($name eq "abslayout") {
    return(1);
  }
  if($name eq "comp") {
    return(1);
  }

  # unknown element
  print STDERR "$self->{INSTNAME} WARNING: unknown tag >$name<\n";
}

sub lml_end {
  my $self=shift; # object reference
  my $o   =shift;
  my $name=shift;
#    print STDERR "$self->{INSTNAME} lml_end >$name< \n";

  if($name=~/data/) {
    if(!$self->{LASTINFOID}) {
      pop(@{$o->{NODEDISPLAYSTACK}});
    }
    if($self->{LASTCHARTID}) {
      $o->{LASTCHARTDATANAME}=undef;
    }
  }

  if(($name=~/el\d/) || ($name eq 'img') || ($name eq 'scheme')) {
    pop(@{$o->{NODEDISPLAYSTACK}});
  }
  if($name=~/nodedisplaylayout/) {
    pop(@{$o->{NODEDISPLAYSTACK}});
  }
  if($name=~/schemehint/) {
    pop(@{$o->{NODEDISPLAYSTACK}});
  }
  if($name=~/nodedisplay/) {
    pop(@{$o->{NODEDISPLAYSTACK}});
    $o->{LASTNODEDISPLAYID} = undef;
  }
  if($name=~/table/) {
    $o->{LASTTABLEID} = undef;
  }
  if($name=~/tablelayout/) {
    $o->{LASTTABLELAYOUTID} = undef;
  }
  if($name=~/column/) {
    $o->{LASTCOLUMNID} = undef;
  }
  if($name=~/pattern/) {
    $o->{LASTPATTERNLIST} = undef;
  }
  if($name=~/info/) {
    $o->{LASTINFOID} = undef;
  }
  if($name=~/splitlayout/) {
    pop(@{$o->{SPLITLAYOUTSTACK}});
    $o->{LASTSPLITLAYOUTID} = undef;
    # print STDERR Dumper($o->{SPLITLAYOUT});
  }
  if($name=~/chart/) {
    $o->{LASTCHARTID} = undef;
  }
  if($name=~/x/) {
    $o->{LASTAXESID} = undef;
  }
  if($name=~/y/) {
    $o->{LASTAXESID} = undef;
  }
  if( ($name=~/top/) || ($name eq 'bottom') || ($name=~/left/) || ($name eq 'right') ) {
    pop(@{$o->{SPLITLAYOUTSTACK}});
  }
}


sub write_lml {
  my($self) = shift;
  my $outfile  = shift;
  my($k,$rc,$id,$c,$key,$ref,$t);
  my $val;
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
    $t=0;
    foreach $k (sort keys %{$self->{DATA}->{OBJECT}->{$id}}) {
      printf(OUT " %s=\"%s\"",$k,$self->{DATA}->{OBJECT}->{$id}->{$k});$t=1;
    }
    printf(OUT "/>\n");
    print "write_lml: WARNING: object with id '$id' has no attributes\n" if($t==0);
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
      $val = defined($self->{DATA}->{INFODATA}->{$id}->{$k}) ? $self->{DATA}->{INFODATA}->{$id}->{$k} : "";
      printf(OUT "<data key=\"%s\" value=\"%s\"/>\n",$k,$val);
    }
    printf(OUT "</info>\n");
  }
  printf(OUT "</information>\n");

  if(exists($self->{DATA}->{TABLE})) {
    foreach $id (sort keys %{$self->{DATA}->{TABLE}}) {
      my $table=$self->{DATA}->{TABLE}->{$id};
      printf(OUT "<table ");
      for $key ("id", "gid","name","contenttype","description","title") {
        printf(OUT " %s=\"%s\"",$key,  $table->{$key}) if (exists($table->{$key}) && defined($table->{$key}));
      }
      printf(OUT ">\n");

      foreach $k (sort keys %{$table->{column}}) {
        # print STDERR "$id $k ",Dumper($table->{column}->{$k});
        printf(OUT "<column");
        for $key ("id","name","sort","description","type") {
          printf(OUT " %s=\"%s\"",$key,  $table->{column}->{$k}->{$key}) if (exists($table->{column}->{$k}->{$key}));
        }
        printf(OUT "/>\n");
      }
      foreach $k (sort keys %{$table->{row}}) {
        printf(OUT "<row  %s=\"%s\">\n","oid",$k);
        foreach $c (sort {$a <=> $b} keys %{$table->{row}->{$k}->{cell}}) {
          if (exists($table->{row}->{$k}->{cell}->{$c}->{cid})) {
            printf(OUT "<cell %s=\"%s\" %s=\"%s\"/>\n","value",$table->{row}->{$k}->{cell}->{$c}->{value},"cid",$table->{row}->{$k}->{cell}->{$c}->{cid});
          } else {
            printf(OUT "<cell %s=\"%s\"/>\n","value",$table->{row}->{$k}->{cell}->{$c}->{value});
          }
        }
        printf(OUT "</row>\n");
      }
      printf(OUT "</table>\n");
    }
  }

  if(exists($self->{DATA}->{TABLELAYOUT})) {
    foreach $id (sort keys %{$self->{DATA}->{TABLELAYOUT}}) {
      my $tablelayout=$self->{DATA}->{TABLELAYOUT}->{$id};
      printf(OUT "<tablelayout ");
      for $key ("id","gid","active","contenthint") {
        printf(OUT " %s=\"%s\"",$key,  $tablelayout->{$key}) if (exists($tablelayout->{$key}) && defined($tablelayout->{$key}));
      }
      printf(OUT ">\n");
      foreach $k (sort {$a <=> $b} keys %{$tablelayout->{column}}) {
        printf(OUT "<column");
        for $key ("cid","pos","sorted","width","active","key") {
          if(exists($tablelayout->{column}->{$k}->{$key})) {
            printf(OUT " %s=\"%s\"",$key,  $tablelayout->{column}->{$k}->{$key});
          }
        }
        if(exists($tablelayout->{column}->{$k}->{pattern})) {
          printf(OUT ">\n");
          printf(OUT " <pattern>\n");
          foreach $ref (@{$tablelayout->{column}->{$k}->{pattern}}) {
            printf(OUT " <%s regexp=\"%s\"/>\n",$ref->[0],$ref->[1]) if (($ref->[0] eq "include") || ($ref->[0] eq "exclude") );
            printf(OUT " <%s rel=\"%s\" value=\"%s\"/>\n",
                        $ref->[0],
                        &LML_da_util::unescape_special_characters($ref->[1]),
                        ,$ref->[2]) if (($ref->[0] eq "select") );
          }
          
          printf(OUT " </pattern>\n");
          printf(OUT "</column>\n");
        } else {
          printf(OUT "/>\n");
        }
      }
      printf(OUT "</tablelayout>\n");
    }
  }


  if(exists($self->{DATA}->{NODEDISPLAYLAYOUT})) {
    foreach $id (sort keys %{$self->{DATA}->{NODEDISPLAYLAYOUT}}) {
      my $ndlayout=$self->{DATA}->{NODEDISPLAYLAYOUT}->{$id};
      printf(OUT "<nodedisplaylayout ");
      for $key ("id","gid","active") {
        printf(OUT " %s=\"%s\"",$key,  $ndlayout->{$key}) if (exists($ndlayout->{$key}));
      }
      printf(OUT ">\n");
      if(defined($ndlayout->{schemehint}) ) {
        print OUT "<schemehint>\n";
        print OUT $ndlayout->{schemehint}->get_xml_tree(1);
        print OUT "</schemehint>\n";
      }
      print OUT $ndlayout->{tree}->get_xml_tree(0);
      printf(OUT "</nodedisplaylayout>\n");
    }
  }

  if(exists($self->{DATA}->{NODEDISPLAY})) {
    foreach $id (sort keys %{$self->{DATA}->{NODEDISPLAY}}) {
      my $nd=$self->{DATA}->{NODEDISPLAY}->{$id};
      printf(OUT "<nodedisplay id=\"%s\" title=\"%s\">\n", $nd->{id}, $nd->{title});
      if(exists($nd->{schemeroot})) {
        print OUT "<scheme>\n";
        print OUT $nd->{schemeroot}->get_xml_tree(1);
        print OUT "</scheme>\n";
      }
      if(exists($nd->{dataroot})) {
        print OUT "<data>\n";
        print OUT $nd->{dataroot}->get_xml_tree(1);
        print OUT "</data>\n";
      }
      printf(OUT "</nodedisplay>\n");
    }
  }

  if(exists($self->{DATA}->{SPLITLAYOUT})) {
    foreach $id (sort keys %{$self->{DATA}->{SPLITLAYOUT}}) {
      my $sl=$self->{DATA}->{SPLITLAYOUT}->{$id};
      my $attr="";
      if (exists($sl->{divpos})) {
        $attr.="divpos=\"$sl->{divpos}\"";
      };
      printf(OUT "<splitlayout id=\"%s\" %s>\n", $sl->{id}, $attr);
      if(exists($sl->{tree})) {
        print OUT $sl->{tree}->get_xml_tree(1);
      }
      printf(OUT "</splitlayout>\n");
    }
  }
  
  if(exists($self->{DATA}->{CHART})) {
    foreach $id (sort keys %{$self->{DATA}->{CHART}}) {
      my ($name,$n);
      my $chart=$self->{DATA}->{CHART}->{$id};
      printf(OUT "<chart ");
      for $key ("id", "title") {
        printf(OUT " %s=\"%s\"",$key,  $chart->{$key}) if (exists($chart->{$key}) && defined($chart->{$key}));
      }
      printf(OUT ">\n");

      if(exists($chart->{axes})) {
        printf(OUT "<axes>\n");
        my ($xy,$x,$y);
        for $xy ("x","y") {
          printf(OUT "<$xy");
          for $key ("type","unit","label","min","max","ticcount","dist","undef") {
            printf(OUT " %s=\"%s\"",$key,  $chart->{axes}->{$xy}->{$key}) if (exists($chart->{axes}->{$xy}->{$key}));
          }
          printf(OUT ">\n");
          if(exists($chart->{axes}->{$xy}->{ticlabels})) {
            printf(OUT "<ticlabels>\n");
            for($n=0;$n<=$#{$chart->{axes}->{$xy}->{ticlabels}->{pos}};$n++) {
              printf(OUT  "<label %s=\"%s\" %s=\"%s\"/>\n",
                          "pos",$chart->{axes}->{$xy}->{ticlabels}->{pos}->[$n],
                          "text",$chart->{axes}->{$xy}->{ticlabels}->{text}->[$n]);
            }
            printf(OUT "</ticlabels>\n");
          }
          # todo ticlabels
          printf(OUT "</$xy>\n");
        }
        printf(OUT "</axes>\n");
      }
      foreach $name (sort keys %{$chart->{data}}) {
        printf(OUT "<data ");
        for $key ("name","description") {
          printf(OUT " %s=\"%s\"",$key,  $chart->{data}->{$name}->{$key}) if (exists($chart->{data}->{$name}->{$key}));
        }
        printf(OUT ">\n");
        for($n=0;$n<=$#{$chart->{data}->{$name}->{p}->{x}};$n++) {
          printf(OUT  "<p %s=\"%s\" %s=\"%s\"/>\n",
                      "x",$chart->{data}->{$name}->{p}->{x}->[$n],
                      "y",$chart->{data}->{$name}->{p}->{y}->[$n]);
        }
        printf(OUT "</data>\n");
      }
      printf(OUT "</chart>\n");
    }
  }

  printf(OUT "</lml:lgui>\n");
  
  close(OUT);

  my $tdiff=time-$tstart;
  printf("$self->{INSTNAME} wrote  XML in %6.4f sec to %s\n",$tdiff,$outfile) if($self->{VERBOSE});
  
  return($rc);
}

sub check_lml {
  my($self) = shift;

  {
    my($type,%types,$id);
    if($self->{DATA}->{TABLELAYOUT}) {
      foreach $id (keys %{$self->{DATA}->{TABLELAYOUT}}) {
        $self->_check_lml_tablelayout_width($self->{DATA}->{TABLELAYOUT}->{$id});
        $self->_check_lml_tablelayout_pos($self->{DATA}->{TABLELAYOUT}->{$id});
      }
    }
  }
  return(1);
} 

sub _check_lml_tablelayout_width {
  my($self) = shift;
  my($tlayoutref) = @_;
  my($cid, $numcolumns, $wsum, $wsumweight);

  $numcolumns=scalar keys(%{$tlayoutref->{column}});
  
  $wsum=0.0;
  foreach $cid (sort {$a <=> $b} (keys(%{$tlayoutref->{column}}))) {
    next if($tlayoutref->{column}->{$cid}->{active} eq "false");
    $tlayoutref->{column}->{$cid}->{width}=1.0 if(!exists($tlayoutref->{column}->{$cid}->{width}));
    $tlayoutref->{column}->{$cid}->{width}=1.0 if($tlayoutref->{column}->{$cid}->{width}<=0);
    $wsum+=$tlayoutref->{column}->{$cid}->{width};
  }
  if($wsum>0)  {$wsumweight=1.0/$wsum;}
  else         {$wsumweight=1.0;}
  foreach $cid (sort {$a <=> $b} (keys(%{$tlayoutref->{column}}))) {
    next if($tlayoutref->{column}->{$cid}->{active} eq "false");
    $tlayoutref->{column}->{$cid}->{width}*=$wsumweight;
  }
  
  return(1);
} 

sub _check_lml_tablelayout_pos {
  my($self) = shift;
  my($tlayoutref) = @_;
  my($cid, $numcolumns, $pos);

  $numcolumns=scalar keys(%{$tlayoutref->{column}});
  
  $pos=0;
  foreach $cid (sort {&_sort_tlayout_pos($tlayoutref,$a,$b)} (keys(%{$tlayoutref->{column}}))) {
    $tlayoutref->{column}->{$cid}->{pos}=$pos;
    $pos++;
  }

  return(1);
} 


sub _sort_tlayout_pos {
  my($tlayoutref,$aa,$bb)=@_;

  # pos attribute
  my $apos=1e20;
  my $bpos=1e20;
  $apos=$tlayoutref->{column}->{$aa}->{pos} if(exists($tlayoutref->{column}->{$aa}->{pos}));
  $bpos=$tlayoutref->{column}->{$bb}->{pos} if(exists($tlayoutref->{column}->{$bb}->{pos}));

  # active attribute
  my $aactive="false";
  my $bactive="false";
  $aactive=$tlayoutref->{column}->{$aa}->{active} if(exists($tlayoutref->{column}->{$aa}->{active}));
  $bactive=$tlayoutref->{column}->{$bb}->{active} if(exists($tlayoutref->{column}->{$bb}->{active}));

  if($apos != $bpos) {
    return($apos <=> $bpos);
  } else {
    if($aactive ne $bactive) {
      return($aactive cmp $bactive);	    
    } else {
      return($aa <=> $bb);	    
    }
  }
}
  
1;
