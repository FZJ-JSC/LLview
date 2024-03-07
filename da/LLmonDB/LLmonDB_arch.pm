# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LLmonDB;

my $VERSION='$Revision: 1.00 $';
my $debug=0;

use strict;
use warnings::unused;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );
use IO::File;
use Parallel::ForkManager;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use LML_da_util qw( check_folder sec_to_date );


sub archive_data {
  my($self) = shift;
  my($dblist,$MAX_PROCESSES) = @_;
  my($db,$table,$archopts,$optref,$tables,$rc);
  my $currentts=time();
  my $currentdate=sec_to_date($currentts);
  printf("%s  LLmonDB: start archive_data at $currentdate\n",$self->{INSTNAME}) if($debug>=3);

  # global options, default
  $archopts->{archive_data}=1;
  $archopts->{remove_data}=1;
  $archopts->{archdir}=".";
  $archopts->{currentts}=$currentts;
  $archopts->{currentdate}=$currentdate;

  my $db_to_arch=undef;
  if(defined($dblist)) {
    foreach my $d (split(/\s*,\s*/,$dblist)) {
      $db_to_arch->{$d}=1;
    }
  }
  
  if(exists($self->{CONFIGDATA}->{paths})) {
    if(exists($self->{CONFIGDATA}->{paths}->{archdir})) {
      $archopts->{archdir}=$self->{CONFIGDATA}->{paths}->{archdir};
    }
  }
  # Creating folder if it does not exist
  &check_folder($archopts->{archdir}.'/');

  # check global options from config file
  if(exists($self->{CONFIGDATA}->{archive})) {
    for my $key ("archive_data", "remove_data") {
      if(exists($self->{CONFIGDATA}->{archive}->{$key})) {
        if ($self->{CONFIGDATA}->{archive}->{$key}=~/(yes|1)/i) {
          $archopts->{$key}=1;
        } else {
          $archopts->{$key}=0;
        }
      }
    }
  }
  
  # look up db/table combinations, needed later for non_existent option
  foreach $db (keys(%{$self->{CONFIGDATA}->{databases}})) {
    foreach my $t (@{$self->{CONFIGDATA}->{databases}->{$db}->{tables}}) {
      my $tableref=$t->{table};
      $table=$tableref->{name};
      $tables->{$db}->{$table}=1;
    }
  }

  # parallel processing
  my $pm = Parallel::ForkManager->new($MAX_PROCESSES);

  my $dbcnt=0;
  # run over all DBs and archive data
  DB_LOOP:
  foreach $db (keys(%{$self->{CONFIGDATA}->{databases}})) {
    printf("%s  LLmonDB:  -> check DB $db\n",$self->{INSTNAME}) if($self->{VERBOSE});
    if(defined($db_to_arch)) {
      if(!exists($db_to_arch->{$db})) {
        printf("%s  LLmonDB:     -> skip DB $db due to dblist option\n",$self->{INSTNAME}) if($self->{VERBOSE});
        next;
      }
    }

    $dbcnt++;
    # Forks and returns the pid for the child: # my $pid = 
    $pm->start($db) and next DB_LOOP;

    my $qtime=time();
    foreach my $t (@{$self->{CONFIGDATA}->{databases}->{$db}->{tables}}) {
      my $tableref=$t->{table};
      $table=$tableref->{name};
      if(exists($tableref->{options})) {
        $optref=$tableref->{options};
        if( exists($optref->{archive}) ) {
          # 'non_existent: ntable/ncol' --> archive all entries which do not exist in ntable in column ncol
          if(exists($optref->{archive}->{non_existent})) {
            my $what=$optref->{archive}->{non_existent};
            if($what=~/^\s*(.*)\/(.*)\s*$/) {
              my($ntable,$ncol)=($1,$2);
              if(exists($tables->{$db}->{$ntable})) {
                my $stime=time();
                $rc=$self->archive_data_non_existent($db,$table,$tableref,$ntable,$ncol,$archopts);
                printf("%s  LLmonDB:  archive %6d entries of table %15s/%-35s in %8.5fs (non_existent $ntable/$ncol)\n",
                        $self->{INSTNAME},$rc,$db,$table,time()-$stime);
              }
            }
          }

          # 'limit: <expr>, <expr>,
          #    expression: max(col)-val    
          if(exists($optref->{archive}->{limit})) {
            my $expressions=$optref->{archive}->{limit};
            my $stime=time();
            $rc=$self->archive_data_by_limit($db,$table,$tableref,$expressions,$archopts);
            printf("%s  LLmonDB:  archive %6d entries of table %15s/%-35s in %8.5fs (by expressions $expressions)\n",
                    $self->{INSTNAME},$rc,$db,$table,time()-$stime);
          }

          # limit_aggr_time: [ 1440, 4320, 17280, 32560, 129600, 525600 ]     # in minutes
          # limit_aggr_time_var: ts
          if(exists($optref->{archive}->{limit_aggr_time})) {
            my $limitlist=$optref->{archive}->{limit_aggr_time};
            my $limitvar=$optref->{archive}->{limit_aggr_time_var};
            my $limitres=$optref->{update}->{sql_update_contents}->{aggr_by_time_resolutions};
            my $stime=time();
            $rc=$self->archive_data_by_limit_aggr_time($db,$table,$tableref,$limitlist,$limitres,$limitvar,$archopts);
            printf("%s\t LLmonDB:     archive %6d entries of table %25s/%-40s in %8.5fs (by aggr_time %s)\n",
                  $self->{INSTNAME},$rc,$db,$table,time()-$stime,join(",",@{$limitlist}));
          }
        }
      }
    }
    printf("%s  LLmonDB:     query db [%2d]%-30s in %4.2fs\n",$self->{INSTNAME},$dbcnt,$db,time()-$qtime) if($self->{VERBOSE});
    $pm->finish(0); # Terminates the child process
  }
  printf("%s LLmonDB: Waiting for children (%d processes)\n",$self->{INSTNAME},scalar $pm->running_procs());
  $pm->wait_all_children;
  printf("%s LLmonDB: Children ready (%d processes)\n",$self->{INSTNAME},scalar $pm->running_procs());

  printf("%s  LLmonDB: end archive_data \n",$self->{INSTNAME}) if($debug>=3);
  return();
}



sub archive_data_non_existent {
  my($self) = shift;
  my($db,$table,$tableref,$ntable,$ncol,$archopts)=@_;
  my($where,$rc);

  $where=sprintf("(%s not in (select %s from %s))",$ncol,$ncol,$ntable);
  $rc=$self->archive_process_data($db,$table,$tableref,$where,$archopts);
  return($rc);
}

sub archive_data_by_limit {
  my($self) = shift;
  my($db,$table,$tableref,$expressions,$archopts)=@_;

  # scan expressions
  my(@whereparts,$where,$rc);
  
  foreach my $expr (split/\s*,\s*/,$expressions) {
    if($expr=~/^\s*max\(([^\)]+)\)\s*-\s*(.*)\s*$/) {
      my($col,$subvalue)=($1,$2);
      my $maxvalue=$self->query($db,$table,
              {
              type => 'get_max',
              hash_key => $col
              });
      # printf("%s  LLmonDB:  $db,$table,$col  maxvalue=%s TS_ERROR\n",$self->{INSTNAME}, $maxvalue);
      my $val=$self->timeexpr_to_sec($subvalue);
      if($val >= 0 ) {
        $maxvalue-=$val;
      } else {
        printf STDERR ("%s  LLmonDB:    WARNING: unknown time expr '$subvalue'\n",$self->{INSTNAME});
      }
      push(@whereparts,"( ($col<$maxvalue) AND ($col>0) )");
    } else {
      printf STDERR ("%s  LLmonDB:    WARNING: unknown pattern '$expr'\n",$self->{INSTNAME});
    }
  }
  $where=join(" AND ",@whereparts);
  # print "TMPDEB: $expressions, $where\n";
  $rc=$self->archive_process_data($db,$table,$tableref,$where,$archopts);

  return($rc);
}

sub archive_data_by_limit_aggr_time {
  my($self) = shift;
  my($db,$table,$tableref,$limitlist,$limitres,$limitvar,$archopts)=@_;

  # get max value for TS var 
  my $maxvalue=$self->query($db,$table,
                            {
                              type => 'get_max',
                              hash_key => $limitvar
                            });
  # printf("%s\t LLmonDB:  $db,$table,$limitvar  maxvalue=%s\n",$self->{INSTNAME}, $maxvalue);
  
  return(0) if(!defined($maxvalue));

  # scan expressions
  my(@whereparts,$where,$rc);
  my @l_list=@{$limitlist}; my @l_res=@{$limitres};
  
  while(my $limit=shift @l_list) {
    my $res=shift @l_res;
    my $maxts=$maxvalue-($limit*60);
    push(@whereparts,"( (_time_res=$res) AND ($limitvar<$maxts) )");
  }
  $where=join(" OR ",@whereparts);
  $rc=$self->archive_process_data($db,$table,$tableref,$where,$archopts);

  return($rc);
}

sub archive_process_data {
  my($self) = shift;
  my($db,$table,$tableref,$where,$archopts)=@_;
  my $columns=$tableref->{columns};

  my($colref,$colsref,$filename);

  # get config of table and mapping of attributes from config file
  foreach $colref (@{$columns}) {
    my $name=$colref->{name};
    push(@{$colsref},$name);
  }

  # get number of affected entries
  
  my $count=$self->query($db,$table,
            {
              type => 'get_count',
              where => $where
            });
  
  if($count==0) {
    printf("%s  LLmonDB:        -> no data to archive for $db/$table\n",$self->{INSTNAME}) if($self->{VERBOSE});
    return($count);
  }

  if($archopts->{archive_data}) {
    # check arch file
    $filename=sprintf("%s/db_%s_tab_%s_date_%s.csv",
            $archopts->{archdir},
            $db,
            $table,
            LLmonDB::sec_to_date_week_fn($archopts->{currentts})
          );
    my $fh = IO::File->new();
    if (! $fh->open(">> $filename")) {
      print STDERR "$self->{INSTNAME} LLmonDB:    ERROR: cannot open $filename\n";
    } else {
      printf( $fh  "#DATE: %s TS:%s\n",$archopts->{currentdate},$archopts->{currentts});
      printf( $fh  "#COUNT: %d\n",$count);
      printf( $fh  "#COLUMNS: %s\n",join(",",@{$colsref}));

      # store data in arch file
      $self->query($db,$table,
                    {
                    type => 'get_execute',
                    columns => $colsref,
                    where => $where,
                    execute => sub {
                      my @values=map {($_=~/,/) ? "\"".$_."\"" : $_ } @_;
                      print $fh join(",",@values),"\n";
                    }
                    });
      $fh->close();
    }
    printf("%s  LLmonDB:    -> archived data to $filename ($count entries)\n",$self->{INSTNAME}) if($self->{VERBOSE});
  }

  if($archopts->{remove_data}) {
    # store data in arch file
    my $rcount=$self->delete($db,$table,
                            {
                            type => 'some_rows',
                            where => $where
                            });
    printf("%s  LLmonDB:    -> removed $rcount entries\n",$self->{INSTNAME}) if($self->{VERBOSE});
  }

  return($count);
  $self->{A}=0;  #dummy statement to avoid unused warning
}

1;