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

sub get_datasetstat_from_DB {
  my $self = shift;
  my($stat_db,$stat_table,$where)=@_;

  # print "start get_datasetstat_from_DB $stat_db,$stat_table\n";
  my $dataref=$self->{DB}->query($stat_db,$stat_table,
                                  {
                                    type => "hash_values",
                                    hash_keys => "dataset",
                                    where => $where,
                                    hash_value => "name,ukey,lastts_saved,checksum,status"
                                  });
  $self->{DATASETSTAT}->{$stat_db}->{$stat_table}=$dataref;
  # print "end get_datasetstat_from_DB $stat_db,$stat_table,$where\n";
}

sub cleanup_datasetstat {
  my $self = shift;
  my($stat_db,$stat_table)=@_;

  my $ds=$self->{DATASETSTAT}->{$stat_db}->{$stat_table};
  foreach my $key (keys(%{$ds})) {
    # remove entries which are marked to be removed (already archived)
    if($ds->{$key}->{"status"} == 3) {
      delete($ds->{$key});
    }
  }
}

sub save_datasetstat_in_DB {
  my $self = shift;
  my($stat_db,$stat_table,$where)=@_;

  # print "start save_datasetstat_in_DB $stat_db,$stat_table\n";
  # remove info from table
  if($where) {
    $self->{DB}->delete($stat_db,$stat_table,
                        {
                        type => 'some_rows',
                        where => $where    
                        });
  } else {
    $self->{DB}->delete($stat_db,$stat_table,
                        {
                        type => 'all_rows'
                        });
  }
  # add new dirstat to DB table
  my @tabstatcolsref=("dataset","name","ukey","lastts_saved","checksum","status");
  my $seq=$self->{DB}->start_insert_sequence($stat_db,$stat_table,\@tabstatcolsref);
  my $ds=$self->{DATASETSTAT}->{$stat_db}->{$stat_table};
  foreach my $key (keys(%{$ds})) {
    if(!defined($ds->{$key}->{"dataset"})) {
      print STDERR "[save_datasetstat_in_DB] ERROR dataset for key $key not defined\n";
      next; 
    };
    if(!defined($ds->{$key}->{"name"})) {
      print STDERR "[save_datasetstat_in_DB] ERROR name for key $key not defined\n";
      next; 
    };
    if(!defined($ds->{$key}->{"ukey"})) {
      print STDERR "[save_datasetstat_in_DB] ERROR ukey for key $key not defined\n";
      next; 
    };
    if(!defined($ds->{$key}->{"lastts_saved"})) {
      print STDERR "[save_datasetstat_in_DB] ERROR lastts_saved for key $key not defined\n";
      next; 
    };
    if(!defined($ds->{$key}->{"checksum"})) {
      print STDERR "[save_datasetstat_in_DB] ERROR checksum for key $key not defined\n";
      next; 
    };
    if(!defined($ds->{$key}->{"status"})) {
      print STDERR "[save_datasetstat_in_DB] ERROR status for key $key not defined\n";
      next; 
    };
    my @data = ($ds->{$key}->{"dataset"},
                $ds->{$key}->{"name"},
                $ds->{$key}->{"ukey"},
                $ds->{$key}->{"lastts_saved"},
                $ds->{$key}->{"checksum"},
                $ds->{$key}->{"status"});
    $self->{DB}->insert_sequence($stat_db,$stat_table,$seq,\@data  );
  }
  $self->{DB}->end_insert_sequence($stat_db,$stat_table,$seq);

  # print "end save_datasetstat_in_DB $stat_db,$stat_table\n";
}

1;
