# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LML_da_historyMGR;

my $VERSION='$Revision: 1.00 $';
my($debug)=0;

use strict;
use Data::Dumper;
# use XML::Simple;
use Time::Local;
use Time::HiRes qw ( time );
use lib "$FindBin::RealBin/../lib";
use LML_da_util qw( check_folder sec_to_date );

use LML_file_obj;

sub new {
  my $self    = {};
  my $proto   = shift;
  my $class   = ref($proto) || $proto;
  printf("\tLML_da_historyMGR: new %s\n",ref($proto)) if($debug>=3);

  $self->{HISTDIR}       = shift;
  $self->{FORMAT}        = shift;
  $self->{VERBOSE}       = shift;
  $self->{ONLYDB}        = shift;
  bless $self, $class;
  return $self;
}

sub store {
  my($self)  = shift;
  my($infile) = shift;
  my($found,$tarfile,$filename);
  my $rc=0;
  
  $found=0;
  &check_folder($self->{HISTDIR}.'/');

  print "TMPDEB: inputtype=$self->{FORMAT} file=$infile\n" if($self->{VERBOSE});

  if($self->{FORMAT} eq "LML") {
    $found=$self->_getdate_LML($infile);
  }
  if($self->{FORMAT} eq "llview") {
    $found=$self->_getdate_LLview($infile);
  }
  if($found) {
    printf("HistoryMGR:  found in $infile data set for %s %s %s %s %s %s\n",
              $self->{MONTH},	    $self->{DAY},	    $self->{YEAR},
              $self->{HOUR},	    $self->{MIN},	    $self->{SEC}    ); 
    ($tarfile,$filename)=$self->_updatedbfiles();
    if(!$self->{ONLYDB}) {
      $rc=$self->_addtotarfile($tarfile,$infile,$filename);
    }
  }
  return($rc);
}

sub _getdate_LLview {
  my($self) = shift;
  my($file)=@_;
  my $found=0;

  open(IN,"$file");
  while(<IN>) {
    if(~/system_time=\"(\d+)\/(\d+)\/(\d+)[- ](\d+):(\d+):(\d+)\"/s) {
      my($month,$day,$year,$hour,$min,$sec)=($1,$2,$3,$4,$5,$6);
      $self->{MONTH}=$month;
      $self->{DAY}=$day;
      $self->{YEAR}=$year;
      $self->{HOUR}=$hour;
      $self->{MIN}=$min;
      $self->{SEC}=$sec;
      $found=1;
    }
  }
  close(IN);
  return($found);
}

sub _getdate_LML {
  my($self) = shift;
  my($filename)=@_;
  my $found=0;
  
  my $filehandler=LML_file_obj->new($self->{VERBOSE},$self->{TIMINGS});
  $filehandler->read_lml_fast($filename);
  
  # determine system date
  my $system_time = "unknown";
  {
    my($key,$ref);
    keys(%{$filehandler->{DATA}->{OBJECT}}); # reset iterator
    while(($key,$ref)=each(%{$filehandler->{DATA}->{OBJECT}})) {
      if($ref->{type} eq 'system') {
        next if ($key!~/^sys/); # skip submitting machines from batch system
        $ref=$filehandler->{DATA}->{INFODATA}->{$key};
        if($ref->{system_time}) {
          $system_time=$ref->{system_time};
          printf("scan system: system_time is %s\n",$system_time);
        }
        last; 
      }
    }
  }
  
  if($system_time=~/(\d+)\/(\d+)\/(\d+)-(\d+):(\d+):(\d+)/s) {
    my($month,$day,$year,$hour,$min,$sec)=($1,$2,$3,$4,$5,$6);
    $self->{MONTH}=$month;
    $self->{DAY}=$day;
    $self->{YEAR}=$year;
    $self->{HOUR}=$hour;
    $self->{MIN}=$min;
    $self->{SEC}=$sec;
    $found=1;
  }
  if($system_time=~/(\d\d\d\d)-(\d\d)-(\d\d) (\d+):(\d+):(\d+)/s) {
    my($year,$month,$day,$hour,$min,$sec)=($1,$2,$3,$4,$5,$6);
    $self->{MONTH}=$month;
    $self->{DAY}=$day;
    $self->{YEAR}=$year;
    $self->{HOUR}=$hour;
    $self->{MIN}=$min;
    $self->{SEC}=$sec;
    $found=1;
  }

  #  check for pstat
  if (!$found) {
    {
      my($key,$ref);
      keys(%{$filehandler->{DATA}->{OBJECT}}); # reset iterator
      while(($key,$ref)=each(%{$filehandler->{DATA}->{OBJECT}})) {
        if($ref->{type} eq 'pstat') {
          next if ($key!~/^pstat_(getstep|getjoberrmsg)/); 
          $ref=$filehandler->{DATA}->{INFODATA}->{$key};
          if($ref->{startts}) {
            my $system_time_ts=$ref->{startts};
            $system_time=&sec_to_date($system_time_ts);
            printf("scan system: pstat start_time is %s\n",$system_time);
          }
          last; 
        }
      }
    }
    
    if($system_time=~/(\d+)\/(\d+)\/(\d+)-(\d+):(\d+):(\d+)/s) {
      my($month,$day,$year,$hour,$min,$sec)=($1,$2,$3,$4,$5,$6);
      $self->{MONTH}=$month;
      $self->{DAY}=$day;
      $self->{YEAR}=$year;
      $self->{HOUR}=$hour;
      $self->{MIN}=$min;
      $self->{SEC}=$sec;
      $found=1;
    }
  }
  
  return($found);
}


sub _updatedbfiles {
  my($self) = shift;
  my($file)=@_;
  my($tarfile,$filename,$nr);

  # day-based file
  {
    my $dayfile=sprintf("%s/%02d_%02d_%02d.dat",$self->{HISTDIR},$self->{YEAR},$self->{MONTH},$self->{DAY});
    my (@daytimes,$datestr,$line);
    if(-f $dayfile) {
      open(IN,"$dayfile");
      while($line=<IN>) {
        ($nr,$datestr)=split(/\s+/,$line);
        $daytimes[$nr]=$datestr;
      }
      close(IN);
    }
    $nr=$#daytimes + 1;
    $datestr=sprintf("%02d\/%02d\/%02d-%02d:%02d:%02d",	       
                      $self->{YEAR},     $self->{MONTH},    $self->{DAY},	   
                      $self->{HOUR},	    $self->{MIN},      $self->{SEC}   );
    $daytimes[$nr]=$datestr;
    
    open(OUT,"> $dayfile") || die "could not open $dayfile";
    for($nr=0;$nr<=$#daytimes;$nr++) {
      printf(OUT "%06d %s\n",$nr,$daytimes[$nr]);
    }
    close(OUT);
    $filename=sprintf("%06d.xml.gz",$nr);
  }

  # month-based file
  {
    my $monthfile=sprintf("%s/%02d_%02d.dat",$self->{HISTDIR},$self->{YEAR},$self->{MONTH});
    my (@daytimes,$day,$count,$line);
    for($day=0;$day<=$self->{DAY};$day++) {
      $daytimes[$day]=0;
    }	
    if(-f $monthfile) {
      open(IN,"$monthfile");
      while($line=<IN>) {
        ($day,$count)=split(/\s+/,$line);
        $daytimes[$day]=$count;
      }
      close(IN);
    }
    $daytimes[$self->{DAY}]++;
    
    open(OUT,"> $monthfile");
    for($day=0;$day<=$#daytimes;$day++) {
      printf(OUT "%06d %6d\n",$day,$daytimes[$day]);
    }
    close(OUT);
  }

  # year-based file
  {
    my $yearfile=sprintf("%s/%02d.dat",$self->{HISTDIR},$self->{YEAR});
    my (@mtimes,$month,$count,$line);
    for($month=0;$month<=$self->{MONTH};$month++) {
      $mtimes[$month]=0;
    }	
    if(-f $yearfile) {
      open(IN,"$yearfile");
      while($line=<IN>) {
        ($month,$count)=split(/\s+/,$line);
        $mtimes[$month]=$count;
      }
      close(IN);
    }
    $mtimes[$self->{MONTH}]++;
    
    open(OUT,"> $yearfile");
    for($month=0;$month<=$#mtimes;$month++) {
      printf(OUT "%06d %6d\n",$month,$mtimes[$month]);
    }
    close(OUT);
  }

  $tarfile=sprintf("%s_data_%02d_%02d_%02d.tar",$self->{FORMAT},$self->{YEAR},$self->{MONTH},$self->{DAY});
  
  return($tarfile,$filename);
}

sub _addtotarfile {
  my($self) = shift;
  my($tarfile,$infile,$filename)=@_;
  my($tarcmd,$cmd,$rc);

  if(-f $self->{HISTDIR}."/$tarfile") {
    $tarcmd="tar uf "; 
  } else {
    $tarcmd="tar cf "; 
  }
  if($self->_compress_file($infile,$self->{HISTDIR}."/$filename")==0) {
    $cmd="(cd $self->{HISTDIR};$tarcmd $tarfile $filename)";
    printf STDERR "executing: %s\n",$cmd if($self->{VERBOSE});
    system($cmd);$rc=$?;
    if($rc) {
      printf STDERR "failed executing: %s rc=%d\n",$cmd,$rc; return(-1);
    }
    unlink($self->{HISTDIR}."/$filename");
  }
  return($rc);
}


sub _compress_file {
  my($self) = shift;
  my($file,$newfile)=@_;
  my $rc=0;
  my $cmd="gzip -c -9 < $file > $newfile";
  printf STDERR "executing: %s\n",$cmd if($self->{VERBOSE});
  system($cmd);$rc=$?;
  if($rc) {
    printf STDERR "failed executing: %s rc=%d\n",$cmd,$rc; return(-1);
  }
  return($rc);
}

sub _get_current_date {
  my($self) = shift;
  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$idst)=localtime(time());
  my($date);
  $year=substr($year,1,2);
  $date=sprintf("%02d/%02d/%02d-%02d:%02d:%02d",$mon+1,$mday,$year,$hour,$min,$sec);
  return($date);
}


1;
