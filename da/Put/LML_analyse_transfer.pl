#!/usr/bin/perl -w
# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

use strict;
use Getopt::Long;
use Data::Dumper;

use FindBin;
use lib "$FindBin::RealBin/";
use lib "$FindBin::RealBin/../lib";

my $patint="([\\+\\-\\d]+)";   # Pattern for Integer number
my $patintk="([\\+\\-\\d,]+)";   # Pattern for Integer number, with ','
my $patfp ="([\\+\\-\\d.E]+)"; # Pattern for Floating Point number
my $patwrd="([\^\\s]+)";       # Pattern for Work (all noblank characters)
my $patbl ="\\s+";             # Pattern for blank space (variable length)

#####################################################################
# get command line parameter
#####################################################################

# option handling
my $opt_infile="./tmp/steplogs/transferreports_last.log";
my $opt_outfile="./tmp/transferreports_stat_LML.xml";
my $opt_name="default";
my $opt_verbose=0;
my $opt_timings=0;
my $opt_dump=0;
usage($0) if( ! GetOptions( 
                'verbose'          => \$opt_verbose,
                'infile=s'         => \$opt_infile,
                'outfile=s'        => \$opt_outfile,
                'name=s'           => \$opt_name,
                ) );

if($opt_verbose) {
  printf("infile   = %s\n",$opt_infile);
  printf("outfile  = %s\n",$opt_outfile);
  printf("name     = %s\n",$opt_name);
}

my $stat;
$stat->{$opt_name}->{name}=$opt_name;
open(IN, $opt_infile) or die "cannot open $opt_infile";
while(my $line=<IN>) {
  if($line=~/Number of files: $patintk \(reg: $patintk, dir: $patintk\)/) {
    my($a,$b,$c)=($1,$2,$3);
    $stat->{$opt_name}->{nfiles}=&modint($a);
    $stat->{$opt_name}->{nregfiles}=&modint($b);
    $stat->{$opt_name}->{ndirs}=&modint($c);
  }
  if($line=~/Number of created files\s*[:=]\s+$patintk/) {
    my($a)=($1);
    $stat->{$opt_name}->{ncreate}=&modint($a);
  } 
  if($line=~/Number of deleted files\s*[:=]\s+$patintk/) {
    my($a)=($1);
    $stat->{$opt_name}->{ndelete}=&modint($a);
  }
  if($line=~/Number of regular files transferred\s*[:=]\s+$patintk/) {
    my($a)=($1);
    $stat->{$opt_name}->{nregfilestrans}=&modint($a);
  }
  if($line=~/Total file size\s*[:=]\s+$patintk bytes/) {
    my($a)=($1);
    $stat->{$opt_name}->{totalfilesize}=&modint($a);
  }
  if($line=~/Total transferred file size\s*[:=]\s+$patintk bytes/) {
    my($a)=($1);
    $stat->{$opt_name}->{totalfilesizetrans}=&modint($a);
  }
  if($line=~/Total bytes sent\s*[:=]\s+$patintk/) {
    my($a)=($1);
    $stat->{$opt_name}->{totalbytessent}=&modint($a);
  }
  if($line=~/Total bytes received\s*[:=]\s+$patintk/) {
    my($a)=($1);
    $stat->{$opt_name}->{totalbytesrecv}=&modint($a);
  }
  if($line=~/transfertime\s*[:=]\s+$patfp\s+\($patfp,$patfp\)/) {
    my($a,$b,$c)=($1,$2,$3);
    $stat->{$opt_name}->{transfertime}=&modint($a);
    $stat->{$opt_name}->{ts}=$stat->{$opt_name}->{startts}=&modint($b);
    $stat->{$opt_name}->{endts}=&modint($c);
  }
}
close(IN);
#print Dumper($stat);

&write_lml($opt_outfile,$stat);

sub modint {
  my($number)=@_;
  $number=~s/\,//gs;
  return($number);
}

sub usage {
  die "Usage: $_[0] <options> <filenames> 
                -verbose                 : verbose
                -infile <file>           : input filename (transferlog)
                -outfile <file>          : LML output filename
";
}

sub write_lml {
  my($filename,$stat)=@_;
  my($count,%stepnr);
  
  open(OUT,"> $filename") || die "cannot open file $filename";
  printf(OUT "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  printf(OUT "<lml:lgui xmlns:lml=\"http://eclipse.org/ptp/lml\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n");
  printf(OUT "	xsi:schemaLocation=\"http://eclipse.org/ptp/lml lgui.xsd\"\n");
  printf(OUT "	version=\"0.7\"\>\n");
  printf(OUT "<objects>\n");
  $count=0;
  foreach my $name (sort {$stat->{$a}->{ts} <=> $stat->{$b}->{ts}} (keys(%{$stat}))) {
    $count++;$stepnr{$name}=$count;
    printf(OUT "<object id=\"ts%06d\" name=\"%s\" type=\"transferstat\"/>\n",$count,$name);
  }
  
  printf(OUT "</objects>\n");
  printf(OUT "<information>\n");

  foreach my $name (sort {$stat->{$a}->{ts} <=> $stat->{$b}->{ts}} (keys(%{$stat}))) {
    printf(OUT "<info oid=\"ts%06d\" type=\"short\">\n",$stepnr{$name});
    foreach my $attr (sort (keys(%{$stat->{$name}}))) {
      printf(OUT " <data %-20s value=\"%s\"/>\n","key=\"$attr\"", $stat->{$name}->{$attr});
    }
    printf(OUT "</info>\n");
  }
  printf(OUT "</information>\n");
  printf(OUT "</lml:lgui>\n");
  close(OUT);

}
