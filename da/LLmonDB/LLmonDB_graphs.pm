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

my $patwrd="([\^\\s]+)";       # Pattern for Work (all noblank characters)

# npm install  @mermaid-js/mermaid-cli

sub get_graphsDB {
  my($self) = shift;
  my($db,$md_data_hash);

  printf("\t LLmonDB: graphs, start scan\n") if($debug>=3);
  my ($links);    

  # scan DBs/tables and generate global dependency graph
  foreach $db (sort(keys(%{$self->{CONFIGDATA}->{databases}}))) {
    # next if($db ne "jobreport"); # TMPDEB
    next if( scalar @{$self->{CONFIGDATA}->{databases}->{$db}->{tables}} == 1); 
    my ($table,%tablelinkcnt);
    
    # check tables 
    foreach my $t (@{$self->{CONFIGDATA}->{databases}->{$db}->{tables}}) {
      my $tableref=$t->{table};
      $table=$tableref->{name};
      $tablelinkcnt{$table}=0 if(!exists($tablelinkcnt{$table}));
      
      if(exists($tableref->{options})) {
        # triggered tables
        if(exists($tableref->{options}->{update_trigger})) {
          foreach my $trig_table (@{$tableref->{options}->{update_trigger}}) {
            $links->{$db}->{$table}->{$trig_table}->{trigger}=1;
          }
        }

        # LML import
        if(exists($tableref->{options}->{update})) {
          if(exists($tableref->{options}->{update}->{LML})) {
            my $attr=$tableref->{options}->{update}->{LML};
            $links->{$db}->{'LML'}->{$table}->{LML}->{$attr}=1;
          }
          my $cmd=undef;
          $cmd=$tableref->{options}->{update}->{LLjobreport} if(exists($tableref->{options}->{update}->{LLjobreport}));
          $cmd=$tableref->{options}->{update}->{LMLstat} if(exists($tableref->{options}->{update}->{LMLstat}));
          if(defined($cmd)) {
            if($cmd=~/update_from_other_db\($patwrd,$patwrd,$patwrd\)/) {
              my($tabstat,$updatedtab)=($2,$3);
              $links->{$db}->{$table}->{$tabstat}->{collect_upd}++;
              $links->{$db}->{$table}->{$updatedtab}->{collect_upd}++;
            }
            if(exists($tableref->{columns})) {
              my $col_tables;
              foreach my $ref (@{$tableref->{columns}}) {
                if(exists($ref->{'LLDB_from'})) {
                  my ($db,$tab)=split(/\//,$ref->{'LLDB_from'});
                  $col_tables->{$db}->{$tab}++;
                }
              }
              foreach my $cdb (sort(keys(%{$col_tables}))) {
                my $text="\"\`**$cdb**:\n";
                foreach my $ctab (sort(keys(%{$col_tables->{$cdb}}))) {
                  $text.=sprintf("%s#%d\n",$ctab,$col_tables->{$cdb}->{$ctab});
                  $links->{$cdb}->{$ctab}->{"${db}_${table}"}->{push_attr}=$col_tables->{$cdb}->{$ctab};
                }
                $text.="\`\"";
                $links->{$db}->{"${cdb}"}->{$table}->{collect_attr}=$text;
              }
            }
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
              # print "TMPDEB: $sql\n";
              foreach my $from (@all_matches) {
                # print "TMPDEB: '$from'\n";
                next if($from=~/(\)|;|left|where|group|\()/i);

                foreach my $tab (split(/\s*,\s*/,$from)) {
                  $tab=~s/\s+\w+$//;
                  next if(lc($tab) eq lc($table));
                  if(!exists($tables{$tab})) {
                    if($aggr) {
                      $links->{$db}->{$tab}->{$table}->{aggr}++;
                    } else {
                      $links->{$db}->{$tab}->{$table}->{select}++;
                    }
                    $tables{$tab}=1;
                    $tablelinkcnt{$table}++;
                    $tablelinkcnt{$tab}++;
                  }
                }
              }
            }
          }
        }
      }
    }
    # scan tables without links
    foreach my $ta (sort(keys(%tablelinkcnt))) {
      $links->{$db}->{$table}->{'___no_link___'}=1  if($tablelinkcnt{$ta}==0);
    }
  }

  # scan datasets
  my $datasets=undef;
  if(exists($self->{CONFIGDATA}->{jobreport})) {
    if(exists($self->{CONFIGDATA}->{jobreport}->{datafiles})) {
      $datasets=$self->{CONFIGDATA}->{jobreport}->{datafiles};
    }
  }
  my $join_nr=0;
  my $source_links;
  foreach my $dsref (@{$datasets}) {
    my $ds=$dsref->{dataset};
    next if(!exists($ds->{name}));
    next if(!exists($ds->{filepath}));
    next if(!exists($ds->{data_table}));
    next if(!exists($ds->{data_database}));
    next if(!exists($ds->{stat_table}));
    next if(!exists($ds->{stat_database}));
    my $help=$ds->{filepath};
    $help=~s/\$outputdir\///gs;
    $help=~s/\$/!/gs;
    $help=~s/\{//gs;
    $help=~s/\}//gs;
    my @join_tables=split(/\s*,\s*/,$ds->{data_table});
    if(scalar @join_tables == 1) {
      push(@{$source_links->{$ds->{data_database}}->{$ds->{data_table}}},$help);
    } else {
      # create a virtual join node
      my $jname=join("+",@join_tables);$join_nr++;
      foreach my $t (@join_tables) {
        $links->{$ds->{data_database}}->{$t}->{$jname}->{join}="join_#$join_nr";
      }
      push(@{$source_links->{$ds->{data_database}}->{$jname}},$help);
    }
    $links->{$ds->{stat_database}}->{$ds->{stat_table}}->{$ds->{name}}->{stat}=$help;
  }
  my $fcol_nr=0;
  foreach my $db (sort(keys(%{$source_links}))) {
    foreach my $t (sort(keys(%{$source_links->{$db}}))) {
      $fcol_nr++;
      $links->{$db}->{$t}->{"f_col_$fcol_nr"}->{write}=sprintf("\"`%s`\"",join("\n",@{$source_links->{$db}->{$t}}));
    }
  }

  # create mermaid for each DB
  foreach $db (sort(keys(%{$links}))) {
    my (@import_links,@trigger_links,@aggr_links,@select_links,@upd_links,@col_links,@join_links,%LMLattr);
    my $db_md_data="";
    my $link_cnt=0;	
    my $tab_cnt=0;
    #next if($db ne "pcpucoresstate"); # DEBUG TMPDEB
    my $groups;
    $db_md_data.="graph TD;\n";
    foreach my $from (sort(keys(%{$links->{$db}}))) {
      $tab_cnt++;
      foreach my $to (sort(keys(%{$links->{$db}->{$from}}))) {
        my $l=$links->{$db}->{$from}->{$to};

        if($to ne '___no_link___') {
          my $trigger=exists($l->{trigger});
          if ( ($trigger) && (!exists($l->{aggr})) && (!exists($l->{select})) ) {
            $groups->{tables}->{$from}++;$groups->{ind_tables}->{$to}++;
            push(@trigger_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s -- tr --> %s;\n",$from,$to);
          }
          if(exists($l->{LML}))  {
            foreach my $attr (sort(keys(%{$l->{LML}}))) {
              $groups->{LML}->{"LML_$attr"}++;$groups->{import_tables}->{$to}++;
              push(@import_links,$link_cnt);$link_cnt++;
              $db_md_data.=sprintf("\t\tLML_%s(LML-file, attribute %s) -- import --> %s((%s));\n",$attr,$attr,$to,$to);
              $LMLattr{$attr}++;
            }
          }
          if(exists($l->{aggr}))  {
            $groups->{tables}->{$from}++;$groups->{tables}->{$to}++;
            push(@aggr_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s -- %s%s --> %s;\n",$from,($trigger)?"tr,":"","aggr",$to);
          }
          if(exists($l->{select}))  {
            $groups->{tables}->{$from}++;$groups->{tables}->{$to}++;
            push(@select_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s -- %s%s --> %s;\n",$from,($trigger)?"tr,":"","select",$to);
          }
          if(exists($l->{join}))  {
            $groups->{tables}->{$from}++;$groups->{join}->{$to}++;
            push(@select_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s -- %s%s --> %s;\n",$from,($trigger)?"tr,":"","join",$to);
          }
          if(exists($l->{collect_upd}))  {
            $groups->{tables}->{$from}++;$groups->{tables}->{$to}++;
            push(@upd_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s -- %s%s --> %s;\n",$from,($trigger)?"tr,":"","upd",$to);
          }
          if(exists($l->{collect_attr}))  {
            $groups->{other_DBs}->{$from}++;
            $groups->{"collect_tables_$to"}->{$to}++;
            push(@join_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s[(%s)] -- %s --> %s;\n",$from,$l->{collect_attr},"col_attr",$to);
            $db_md_data.="style $from text-align:left;\n";
          }
          if(exists($l->{push_attr}))  {
            $groups->{tables}->{$from}++;$groups->{other_DBs}->{$to}++;
            push(@col_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s -- %s --> %s[(%s)];\n",$from,"push_attr#".$l->{push_attr},$to,$to,);
          }
          if(exists($l->{write}))  {
            $groups->{tables}->{$from}++;$groups->{"files_$from"}->{$to}++;
            push(@col_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s -- %s --> %s[[%s]];\n",$from,"write",$to,$l->{write});
            $db_md_data.="style $to text-align:left;\n";
          }
          if(exists($l->{stat}))  {
            $groups->{"files_$to"}->{$to}++;
            push(@col_links,$link_cnt);$link_cnt++;
            $db_md_data.=sprintf("\t\t%s[[%s]] -- %s --> %s;\n",$to,$l->{stat},"file_stat",$from);
            $db_md_data.="style $from text-align:left;\n";
          }
        } else {
          # table without link to others
          $groups->{tables}->{$from}++;
          $db_md_data.="\t\t$from;\n";
        }
      }
    }

    foreach my $group (sort(keys(%{$groups}))) {
      $db_md_data.="\t\tsubgraph $group;\n";
      $db_md_data.="\t\t";
      $db_md_data.=join(";",(sort(keys(%{$groups->{$group}}))));
      $db_md_data.=";\n";
      $db_md_data.="\t\tend;\n";
    }
    # Style of triggered links
    $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:3px,stroke:red;\n",join(",",@import_links)) if(@import_links);
    $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:1px,stroke:grey;\n",join(",",@trigger_links)) if(@trigger_links);
    $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:2px,stroke:blue;\n",join(",",@aggr_links)) if(@aggr_links);
    $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:2px,stroke:green;\n",join(",",@select_links)) if(@select_links);
    $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:1px,stroke:darkgreen;\n",join(",",@join_links)) if(@join_links);
    $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:1px,stroke:green;\n",join(",",@upd_links)) if(@upd_links);
    $db_md_data.=sprintf("\t\tlinkStyle %s stroke-width:1px,stroke:lightred;\n",join(",",@col_links)) if(@col_links);

    
    $md_data_hash->{$db}->{nlinks}=$link_cnt;
    $md_data_hash->{$db}->{ntabs}=$tab_cnt;
    $md_data_hash->{$db}->{md}=$db_md_data;
    $md_data_hash->{$db}->{LMLattr}=join(",",keys(%LMLattr));
  
    #	print Dumper($links);
  }
  
  printf("\t LLmonDB: graphs, end scan\n") if($debug>=3);
  return($md_data_hash);
}


sub print_graphsDB {
  my($self) = shift;
  my($outfile)=@_;
  my($db,$md_data);

  $md_data="# LLview DB dependency graphs\n";

  my $md_data_hash=$self->get_graphsDB();

  foreach $db (sort(keys(%{$md_data_hash}))) {
    if($md_data_hash->{$db}->{md} ne "") {
      $md_data.="## Database $db\n";
      $md_data.="```mermaid\n\t";
      $md_data.=$md_data_hash->{$db}->{md};
      $md_data.="```\n";
    } else {
      $md_data.="## Database $db (no dependencies)\n";
    }
  }

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