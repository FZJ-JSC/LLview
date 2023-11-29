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
my($debug)=0;

use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

sub create_directories {
  my $self = shift;
  my $DB=shift;

  my $config_ref=$DB->get_config();

  # print Dumper($config_ref->{jobreport});
  
  # init instantiated variables
  my $varsetref;
  if(exists($config_ref->{jobreport}->{paths})) {
    foreach my $p (keys(%{$config_ref->{jobreport}->{paths}})) {
      $varsetref->{$p}=$config_ref->{jobreport}->{paths}->{$p};
    }
  }

  # get status of directories from DB
  $self->get_dirstat_from_DB($DB);
  
  # process each dirset
  foreach my $subconfig_ref (@{$config_ref->{jobreport}->{directories}}) {
    printf("create_directories: start \n") if($debug);

    # print Dumper($subconfig_ref);
    

    # check for creating subdirs
    if(exists($subconfig_ref->{FORALL})) {
      $self->process_FORALL($DB,$subconfig_ref,$varsetref,\&process_dirlist,$subconfig_ref->{path});
    } else {
      $self->process_dirlist($subconfig_ref->{path},$varsetref);
    }
    printf("create_directories: end\n") if($debug);
  }

  # save status of directories in DB
  $self->save_dirstat_in_DB($DB);

  return();
}

sub process_dirlist {
  my $self = shift;
  my($dirs,$varsetref)=@_;
  printf("process_dirlist: start\n") if($debug);
  
  return if(!defined($dirs));
  foreach my $createpath (split(/\s*,\s*/,$dirs)) {
    while ( my ($key, $value) = each(%{$varsetref}) ) {
      $createpath=~s/\$\{$key\}/$value/gs;
      $createpath=~s/\$$key/$value/gs;
    }
    my $do_chk_mkdir=0;
    if(exists($self->{DIRSTAT}->{$createpath})) {
      # directory already known 
      if($self->{DIRSTAT}->{$createpath}->{"status"} != 1) {  # but does not exist?
        $do_chk_mkdir=1;
      } else {
        # do check again if caller signalled that config has changed
        $do_chk_mkdir=1 if($self->{UPDATECONFIG});
      }
    } else {
      # new directory
      $self->{DIRSTAT}->{$createpath}->{"dir"}=$createpath;
      $self->{DIRSTAT}->{$createpath}->{"lastts_chk"}=$self->{CURRENTTS};
      $do_chk_mkdir=1;
    }
    
    print "process_dirlist3: $createpath do_mkdir=$do_chk_mkdir\n" if($debug);
    if($do_chk_mkdir) {
      if(! -d $createpath) {
        if(mkdir($createpath,0755)) {
          print "create_directories: $createpath created\n";
          $self->{DIRSTAT}->{$createpath}->{"status"}=1;
        } else {
          print "create_directories: $createpath create failed $!\n";
          $self->{DIRSTAT}->{$createpath}->{"status"}=0;
        }
      } else {
        print "create_directories: $createpath already exists\n";
        $self->{DIRSTAT}->{$createpath}->{"status"}=1;
      }
      $self->{DIRSTAT}->{$createpath}->{"lastts_chk"}=$self->{CURRENTTS};
    }
    $self->{DIRSTAT}->{$createpath}->{"lastts_req"}=$self->{CURRENTTS};
  }
  printf("process_dirlist: end\n") if($debug);
}

sub get_dirstat_from_DB {
  my $self = shift;
  my $DB=shift;
  
  my $dataref=$DB->query("jobreport","dirstat",
                          {
                            type => "hash_values",
                            hash_keys => "dir",
                            hash_value => "status,lastts_req,lastts_chk"
                          });
  $self->{DIRSTAT}=$dataref;
  # print Dumper($self->{DIRSTAT});
}

sub save_dirstat_in_DB {
  my $self = shift;
  my $DB=shift;

  # remove info from table
  $DB->delete("jobreport","dirstat",
              {
                type => 'all_rows'
              });

  # add new dirstat to DB table
  my @tabstatcolsref=("dir","lastts_req","lastts_chk","status");
  my $seq=$DB->start_insert_sequence("jobreport","dirstat",\@tabstatcolsref);
  foreach my $key (keys(%{$self->{DIRSTAT}})) {
    next if(!defined($self->{DIRSTAT}->{$key}->{"dir"}));
    next if(!defined($self->{DIRSTAT}->{$key}->{"lastts_req"}));
    next if(!defined($self->{DIRSTAT}->{$key}->{"lastts_chk"}));
    next if(!defined($self->{DIRSTAT}->{$key}->{"status"}));
    my @data= ($self->{DIRSTAT}->{$key}->{"dir"},
                $self->{DIRSTAT}->{$key}->{"lastts_req"},
                $self->{DIRSTAT}->{$key}->{"lastts_chk"},
                $self->{DIRSTAT}->{$key}->{"status"});
    $DB->insert_sequence("jobreport","dirstat",$seq,\@data  );
  }
  $DB->end_insert_sequence("jobreport","dirstat",$seq);
  # print Dumper($self->{DIRSTAT});
}
  
1;
