# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Filipe Guimarães (Forschungszentrum Juelich GmbH) 

package LML_jobreport;

my $VERSION = '$Revision: 1.00 $';

use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

use lib "$FindBin::RealBin/../lib";
use LML_da_util qw( check_folder );

sub process_dataset_datatable {
  my $self = shift;
  my ( $DB, $dataset, $varsetref ) = @_;
  my $file = $dataset->{filepath};
  my $column_definitions = "";

  while ( my ( $key, $value ) = each( %{$varsetref} ) ) {
    $file =~ s/\$\{$key\}/$value/gs;
    $file =~ s/\$$key/$value/gs;
  }

  # print "process_dataset_datatable: file=$file\n";

  my $ds = $self->{DATASETSTAT}->{ $dataset->{stat_database} }->{ $dataset->{stat_table} };

  # scan columns
  my $columns = $dataset->{columns};
  my ( $data, $data_thead, $data_tfilter ) = ( "", "", "" );

  my $theme = exists($dataset->{'ag-grid-theme'}) ? "ag-theme-".$dataset->{'ag-grid-theme'} : "ag-theme-balham";
  my $grid .= "<div id=\"myGrid\" style=\"height: 100%;\" class=\"$theme\"></div>\n";
  
  # my (%groups);
  my $coldefs .= "<script>\n";
  $coldefs .= "  view.columnDefs = [ \n";
  foreach my $colref ( @{$columns} ) { # Each entry (column or column group) of the list
    # Starting column or column group
    $coldefs .= "    {\n";

    while ((my $key, my $ele) = each %{$colref}) {
      if ($key eq 'children') {
        # If the key is 'children',
        # this should be a column group, 
        # so we have to loop over the columns
        $coldefs .= "      $key: [\n";
        foreach my $subele ( @{$ele} ) {
          # Starting child column
          $coldefs .= "        {\n";
          while ((my $subkey, my $value) = each %{$subele}) {
            if (($value =~/\(.*\)\s=>/) || ($subkey=~'filterParams') || ($subkey=~'floatingFilterComponent')) {
              # If element contains a JS function, i.e. is of the form '(...) =>', write it out without quotes
              $coldefs .= "          $subkey: $value,\n";
            } else {
              $coldefs .= "          $subkey: \"$value\",\n";
            }
            if ($subkey eq "cellDataType" &&  $value eq "number") {
              # For columns with number cells, 
              # automatically add the filter, filterParams and floatingFilterComponent
              $coldefs .= "          filter: \"agNumberColumnFilter\",\n";
              $coldefs .= "          filterParams: numberFilterParams,\n";
              $coldefs .= "          floatingFilterComponent: NumberFloatingFilterComponent,\n";
            }
          }
          $coldefs .= "        },\n";
          # Ending child column
        }
        $coldefs .= "      ],\n";
      } else {
        if (($ele =~/\(.*\)\s=>/) || ($key=~'filterParams') || ($key=~'floatingFilterComponent')) {
          # If element contains a JS function, i.e. is of the form '(...) =>', write it out without quotes
          $coldefs .= "      $key: $ele,\n";
        } else {
          $coldefs .= "      $key: \"$ele\",\n";
        }
        if ($key eq "cellDataType" &&  $ele eq "number") {
          # For columns with number cells, 
          # automatically add the filter, filterParams and floatingFilterComponent
          $coldefs .= "        filter: \"agNumberColumnFilter\",\n";
          $coldefs .= "        filterParams: numberFilterParams,\n";
          $coldefs .= "        floatingFilterComponent: NumberFloatingFilterComponent,\n";
        }
      }
    }
    # Ending column or column group
    $coldefs .= "    },\n";
  }
  $coldefs .= "  ]\n";
  $coldefs .= "</script>\n";

  $data .= $grid;
  $data .= $coldefs;

  # print HTML code
  my $fh = IO::File->new();
  &check_folder("$file");
  if ( !( $fh->open("> $file") ) ) {
    print STDERR "LLmonDB:    ERROR, cannot open $file\n";
    die "stop";
    return ();
  }
  $fh->print($data);
  $fh->close();
}

1;
