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
my($debug)=3;

use strict;
use warnings::unused;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );


# npm install  @mermaid-js/mermaid-cli

sub get_graphsDB {
  my($self) = shift;
  my($outfile)=@_;
  my($db,$md_data);

  $md_data="# LLview DB dependency graphs\n";
  
  printf("\t LLmonDB: graphs, start scan\n") if($debug>=3);
  
  foreach $db (sort(keys(%{$self->{CONFIGDATA}->{databases}}))) {
  #	next if($db ne "jobreport"); # DEBUG WF
  print "WF: $db->",scalar @{$self->{CONFIGDATA}->{databases}->{$db}->{tables}},"\n";
  next if( scalar @{$self->{CONFIGDATA}->{databases}->{$db}->{tables}} == 1); 
  my $db_md_data="";
  $db_md_data.="## Database $db\n";
  $db_md_data.="```mermaid\n";
  $db_md_data.="\tgraph TD;\n";

  
  my ($table);
  my $link_cnt=0;
  my (@trigger_links,@aggr_links,@select_links);
    
  # check tables 
  foreach my $t (@{$self->{CONFIGDATA}->{databases}->{$db}->{tables}}) {
    my $tableref=$t->{table};
    $table=$tableref->{name};
    

    if(exists($tableref->{options})) {

    # triggered tables
    if(exists($tableref->{options}->{update_trigger})) {
      foreach my $trig_table (@{$tableref->{options}->{update_trigger}}) {
      push(@trigger_links,$link_cnt);$link_cnt++;
      $db_md_data.=sprintf("\t\t%s -- trigger --> %s;\n",$table,$trig_table);
      }
    }

    # LML import
    if(exists($tableref->{options}->{update})) {
      if(exists($tableref->{options}->{update}->{LML})) {
      my $attr=$tableref->{options}->{update}->{LML};
      $db_md_data.=sprintf("\t\tLML(LML-file, attribute %s) -- import --> %s((%s));\n",$attr,$table,$table);
      }
    }
    
    # dependencies from sql_update_contents
    my %tables;
    if(exists($tableref->{options}->{update})) {
      if(exists($tableref->{options}->{update}->{sql_update_contents})) {
      if(exists($tableref->{options}->{update}->{sql_update_contents}->{sql})) {
        my $sql=$tableref->{options}->{update}->{sql_update_contents}->{sql};

        # inspect SELECT statement
        my $aggr=0;
        my @all_matches = $sql =~ m/select \s*(.*?)\s*(?=from)/gix;
        foreach my $select (@all_matches) {
        $aggr=1 if($select=~/(AVG|SUM|MIN|MAX)/);
        }
        
        # check for FROM-Clause
        @all_matches = $sql =~ m/from \s*(.*?)\s*(?=(left|where|group|[;\)\(]))/gix;
        #		    print "WF: $sql\n";
        foreach my $from (@all_matches) {
#				print "WF: '$from'\n";
        next if($from=~/(\)|;|left|where|group|\()/i);

        foreach my $tab (split(/\s*,\s*/,$from)) {
          $tab=~s/\s+\w+$//;
          next if(lc($tab) eq lc($table));
          if(!exists($tables{$tab})) {
          if($aggr) {
            push(@aggr_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s -- aggr --> %s;\n",$tab,$table);
          } else {
            push(@select_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s -- aggr --> %s;\n",$tab,$table);
          }
          $tables{$tab}=1;
          }
        }
        }
        

      }
      }
    }
    }
  }
  # Style of triggered links
  
  $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:1px,stroke:green;\n",join(",",@trigger_links)) if(@trigger_links);
  $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:1px,stroke:darkblue;\n",join(",",@aggr_links)) if(@aggr_links);
  $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:1px,stroke:blue;\n",join(",",@select_links)) if(@select_links);
  $db_md_data.="```\n";

  if($link_cnt>0) {
    $md_data.=$db_md_data;
  } else {
    $md_data.="## Database $db (no dependencies)\n";
  }
  
  }
  # print Dumper($tableref->{options}->{update_trigger});
  
  if(defined($outfile)) {
  if($outfile eq "stdout") {
    print "LLmonDB_get_graphs: print MD :\n";
    print $md_data;
  } else {
    print "LLmonDB_get_graphs: print MD to $outfile\n";
    open(OUT,"> $outfile") or die("cannot open $outfile for writing, exiting ....");
    print OUT $md_data;
    close(OUT);
  }
  } else {
  print "LLmonDB_get_graphs: print MD :\n";
  print $md_data;
  }

  printf("\t LLmonDB: graphs, end scan\n") if($debug>=3);
  
  
}

1;