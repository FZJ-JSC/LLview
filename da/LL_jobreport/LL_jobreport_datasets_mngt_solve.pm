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

# SQL help:
# restore wrong file in database:
#    delete from datasetstat_csv where ukey in (select ukey from datasetstat_csv group by ukey having count(*)>1) and status=0;
# split stat-table:
#    insert into datasetstat_node_dat (dataset,name,ukey,lastts_saved,status,checksum) SELECT dataset,name,ukey,lastts_saved,status,checksum from datasetstat where(name='fabric_node_dat') ;  
sub solve_datasets {
  my $self = shift;
  my ($DB,$force)=@_;

  my $config_ref=$DB->get_config();

  # init instantiated variables
  my $varsetref;
  if(exists($config_ref->{jobreport}->{paths})) {
    foreach my $p (keys(%{$config_ref->{jobreport}->{paths}})) {
      $varsetref->{$p}=$config_ref->{jobreport}->{paths}->{$p};
    }
  }

  my $fl=$self->get_filelist($varsetref->{outputdir});

  # find datasets to check files
  foreach my $datasetref (@{$config_ref->{jobreport}->{datafiles}}) {
    my $dataset=$datasetref->{dataset};
    
    next if($dataset->{name}!~/(fabric|loadmem|GPU|fsusage)_/);
    next if(!exists($dataset->{stat_table}));

    my $filepath=$dataset->{filepath};

    # while ( my ($key, $value) = each(%{$varsetref}) ) {
    #   $filepath=~s/\$\{$key\}/$value/gs;
    #   $filepath=~s/\$$key/$value/gs;
    # }

    my $pattern=".*";
    my $filepath_fn=$filepath;
    $filepath_fn=~s/.*\///gs;
    if($filepath_fn=~/\$\{J\}/) {
      $pattern=$filepath_fn;
      $pattern=~s/\$\{J\}/\(\.\*\)/s;
      $pattern.="(.gz)?";
    }
    printf("%s work now on dataset %s (%s)\n",$self->{INSTNAME},$dataset->{name},$filepath);
    printf("%s   pattern: '%s'\n",$self->{INSTNAME},$pattern);
    
    # get status of datasets from DB
    $self->get_datasetstat_from_DB($dataset->{stat_database},$dataset->{stat_table});
    my $ds=$self->{DATASETSTAT}->{$dataset->{stat_database}}->{$dataset->{stat_table}};
    
    # check existent states
    my $cnt_not_on_FS=0;
    my $cnt_fn_inconsistence=0;
    if(1) {
      while ( my ($file, $ref) = each(%{$ds}) ) {
        if($file ne $ref->{dataset}) {
          $cnt_fn_inconsistence++;
          printf("%s[%05d] fn inconsistence: [st=%d] %s vs %s\n",$self->{INSTNAME},
                  $cnt_fn_inconsistence,$ref->{status},$file,$ref->{dataset});
        }
        next if($ref->{status}==0);
        my $realfile=sprintf("%s/%s",$self->{OUTDIR},$ref->{dataset});
        if(!exists($fl->{$realfile})) {
          $cnt_not_on_FS++;
          printf("%s[%05d] not_on_FS: [st=%d] %s\n",$self->{INSTNAME},$cnt_not_on_FS,$ref->{status},$realfile);
        }
      }
    }
    
    # check files
    my $cnt_not_in_DB=0;
    if(1) {
      while ( my ($fn,$val) = each(%{$fl}) ) {
        if($fn=~/$pattern/) {
          my $ukey=$1;
          my $shortfile=$fn;$shortfile=~s/$self->{OUTDIR}\///s;
          if(!exists($ds->{$shortfile})) {
            $cnt_not_in_DB++;
            my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($fn);
            $ds->{$shortfile}->{dataset}=$shortfile;
            $ds->{$shortfile}->{name}=$dataset->{name};
            if($shortfile=~/\.gz$/) {
              $ds->{$shortfile}->{status}=2;
            } else {
              $ds->{$shortfile}->{status}=1;
            }
            $ds->{$shortfile}->{lastts_saved}=$mtime;
            $ds->{$shortfile}->{checksum}=0;
            $ds->{$shortfile}->{ukey}=$ukey;

            printf("%s[%05d] not_in_DB: [%s,%s,%s,%s] %s %s\n",$self->{INSTNAME},$cnt_not_in_DB,
                    $ds->{$shortfile}->{status},
                    $ds->{$shortfile}->{lastts_saved},
                    (defined($ds->{$shortfile}->{checksum})?$ds->{$shortfile}->{checksum}:"?"),
                    (defined($ds->{$shortfile}->{ukey})?$ds->{$shortfile}->{ukey}:"?"),
                    &sec_to_date($ds->{$shortfile}->{lastts_saved}),
                    $shortfile);
          }
        }
      }
    }
    if($force) {
      if($cnt_not_in_DB>0) {
        $self->save_datasetstat_in_DB($dataset->{stat_database},$dataset->{stat_table});
        printf("%s saved datasetstat for $dataset->{name}\n", $self->{INSTNAME});
      }
    }
  }

  return();
}

sub get_filelist {
  my $self = shift;
  my ($filepath)=@_;

  my ($fl,$cnt);
  my $starttime=time();
  
  printf("%s scan filepath %s ...\n",$self->{INSTNAME},$filepath);
  open(FL,"find $filepath -type f |");
  $cnt=0;
  while(my $fn=<FL>) {
    chomp($fn);
    $fl->{$fn}=1;
    $cnt++;
  }
  close(FL);
  printf("%s scan filepath %s ... ready, found %d files in %7.4fs\n",$self->{INSTNAME},$filepath,$cnt,time()-$starttime);
  return($fl);
}

1;
