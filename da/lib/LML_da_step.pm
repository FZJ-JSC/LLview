# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 
#    Filipe Guimarães (Forschungszentrum Juelich GmbH) 

package LML_da_step;

my $VERSION='1.1';
my $debug=0;
my $PRIMARKER="LML_da_step";
my $msg;

use strict;
use Data::Dumper;
use Time::Local;
use Time::HiRes qw ( time );

use LML_da_util qw( substitute_recursive logmsg );
use LML_da_step_execute;

sub new {
  my $self    = {};
  my $proto   = shift;
  my $class   = ref($proto) || $proto;
  my $stepdefs     = shift;
  my $globalvarref = shift;
  my $verbose = shift;
  $msg=($debug>=3) ? sprintf("[$PRIMARKER]\t New %s\n",ref($proto)) : ""; logmsg($msg);
  $self->{STEPDEFS}  = $stepdefs;
  $self->{GLOBALVARS}= $globalvarref;
  $self->{VERBOSE}   = $globalvarref->{verbose};
  $self->{DOSTEPFILES} = 1;
  $self->{DOSTEPFILES} = $globalvarref->{do_stepfiles} if(exists($globalvarref->{do_stepfiles}));
  $self->{TMPDIR}    = $globalvarref->{"tmpdir"};
  $self->{PERMDIR}   = $globalvarref->{"permdir"};
  $self->{LOGDIR}    = $globalvarref->{"logdir"};
  $self->{LASTSTEP}  = "__init__";
  bless $self, $class;
  return $self;
}

sub process {
  my($self) = shift;
  my($step,$steprefs,@steplist,%stepstate,$depsteps,$depstep,$stepref,$dep_graph);
  my $rc=0;
  my $loop_done=0;

  $steprefs=$self->{STEPDEFS};
  foreach $step (keys(%{$steprefs})) {
    $steprefs->{$step}->{active}=0  if(!exists($steprefs->{$step}->{active}));
    $steprefs->{$step}->{onerror}="stop"  if(!exists($steprefs->{$step}->{onerror}));
    $steprefs->{$step}->{state}="todo";
  }

  $self->analyse_step_chains();
  $dep_graph=$self->{DEPGRAPH};
  # print "steprefs=",Dumper($steprefs);
  # print "dep_graph=",Dumper($dep_graph);

  # init loop with entry step
  # steps in steplist have (some) fulfilled dependencies and can be execute if all dependencies are fulfilled
  push(@steplist,$dep_graph->{entry});
  $steprefs->{$dep_graph->{entry}}->{state}="inqueue";

  $msg=sprintf("[$PRIMARKER] Initializing execution: %s\n",$self->get_stepstatus_string(\@steplist)); logmsg($msg);
  # start loop over steps
  while(@steplist) {
    $step=shift(@steplist);
    $msg=sprintf("[$PRIMARKER] Start on step=%-15s: %s\n",$step,$self->get_stepstatus_string(\@steplist)); logmsg($msg);
    my $continue=1;
    # check if all dependencies are fulfilled
    my $not_fulfilled=0;
    my $stop_found=0;
    foreach my $pstep (@{$dep_graph->{graph}->{$step}->{prev}}) {
      $not_fulfilled++ if($steprefs->{$pstep}->{state} eq "todo");
      $stop_found++ if($steprefs->{$pstep}->{state} eq "stop_on_error");
      $stop_found++ if($steprefs->{$pstep}->{state} eq "stop_in_deps");
    }
    
    if($stop_found>0) {
      $msg=sprintf("[$PRIMARKER] Stop in deps found for step '$step'\n"); logmsg($msg);
      $steprefs->{$step}->{state}="stop_in_deps";
    }
    
    if(($continue) && ($not_fulfilled>0)) {
      # re-schedule step and continue with next step in list
      $msg=sprintf("[$PRIMARKER] Re-scheduling step '$step'...\n"); logmsg($msg);
      push(@steplist,$step);
      $continue=0;
    }

    # execute step
    if(($continue) && (!$stop_found) && ($steprefs->{$step}->{active})) {
      $rc=$self->execute_step($step);
      $steprefs->{$step}->{state}=($rc)?"failed":"done";
      $msg=sprintf("[$PRIMARKER] Execution of step '$step' $steprefs->{$step}->{state}\n"); logmsg($msg);
    }

    # do not continue with next steps if failed
    if(($continue) && ($steprefs->{$step}->{state} eq "failed") && ($steprefs->{$step}->{onerror} eq "stop")) {
      $steprefs->{$step}->{state}="stop_on_error";
      $msg=sprintf("[$PRIMARKER] Step '$step' failed ($steprefs->{$step}->{state})\n"); logmsg($msg,\*STDERR);
    }
      
    # add depend steps to queue 
    if($continue) {
      foreach my $nstep (@{$dep_graph->{graph}->{$step}->{nxt}}) {
        # skip already queued or executed steps
        $msg=sprintf("[$PRIMARKER] Adding to queue: $nstep\n"); logmsg($msg);
        next if($steprefs->{$nstep}->{state}=~/(inqueue|done|failed)/);
        push(@steplist,$nstep);
        $steprefs->{$nstep}->{state}="inqueue";
      }
    }
    
    $msg=sprintf("[$PRIMARKER] End of step '%s'. %s\n",$step,$self->get_stepstatus_string(\@steplist)); logmsg($msg);
  }
  
  return($rc);
}

sub get_stepstatus_string {
  my($self) = shift;
  my($steplistref)=@_;
  my $steprefs=$self->{STEPDEFS};
  my $dep_graph=$self->{DEPGRAPH};
  my $status_str="STATUS_TODO: ";
  foreach my $step (sort {$steprefs->{$a}->{chainid} <=> $steprefs->{$b}->{chainid}} (keys(%{$steprefs}))) {
    $status_str.=sprintf("[%s:%s]",$step,$steprefs->{$step}->{state}) if($steprefs->{$step}->{state} ne "done");
  }
  if(@{$steplistref}) {
    $status_str.=" QUEUE: ";
    foreach my $step (@{$steplistref}) {
      $status_str.=sprintf("[%s]",$step);
    }
  }
  return($status_str);
}
  
sub execute_step {
  my($self) = shift;
  my($step) = shift;
  my ($stepref,$stepinfile,$stepoutfile);
  my $rc=0;
  my $laststep=$self->{LASTSTEP};
  if($self->{DOSTEPFILES}) {
    $stepinfile=$self->{GLOBALVARS}->{tmpdir}."/datastep_$laststep.xml";
    $stepoutfile=$self->{GLOBALVARS}->{tmpdir}."/datastep_$step.xml";
  }
  $msg=$self->{VERBOSE} ? sprintf("[$PRIMARKER] STEP: %-10s\n",$step) : ""; logmsg($msg);
  
  if($self->{DOSTEPFILES}) {
    $msg=$self->{VERBOSE} ? sprintf("[$PRIMARKER]   (%-30s->%-30s)\n",$stepinfile,$stepoutfile) : ""; logmsg($msg);
    $self->{GLOBALVARS}->{stepinfile}=$stepinfile;
    $self->{GLOBALVARS}->{stepoutfile}=$stepoutfile;
  }

  $stepref=$self->{STEPDEFS}->{$step};
  &substitute_recursive($stepref,$self->{GLOBALVARS}); 

  if($self->{DOSTEPFILES}) {
    if(!-f $stepinfile) {
      $msg=sprintf("[$PRIMARKER] Input file '%s' for step '%s' not found!\n",$stepinfile,$step); logmsg($msg,\*STDERR);
      if($laststep eq "__init__") {
        $msg=sprintf("[$PRIMARKER] --> Generating empty file '%s'...\n",$stepinfile); logmsg($msg);
        system("touch $stepinfile");
      }
    }
    if(-f $stepoutfile) {
      $msg=sprintf("[$PRIMARKER] Deleting output file '%s' from previous run...\n",$stepoutfile); logmsg($msg);
      unlink($stepoutfile);
    }
  }

  if($stepref->{type} eq "execute") {
    my $execobj=LML_da_step_execute->new($stepref,$self->{GLOBALVARS});
    $rc=$execobj->execute();
  }

  if($self->{DOSTEPFILES}) {
    if(! -f $stepoutfile) {
      $msg=sprintf("[$PRIMARKER] Output file not generated by step, renaming input file '%s' to '%s' ...\n",$stepinfile,$stepoutfile); logmsg($msg);
      rename($stepinfile,$stepoutfile);
    }
    $self->{GLOBALVARS}->{stepinfile}="";
    $self->{GLOBALVARS}->{stepoutfile}="";
  }

  $self->{LASTSTEP} = $step;
  return($rc);
}

sub enum_chain {
  my($step,$depnrref,$dep_graph,$stepsref)=@_;
  $$depnrref++;
  # print "enum_chain: $step, $$depnrref\n";
  if(exists($stepsref->{$step})) {
    $stepsref->{$step}->{chainid}=$$depnrref;
  } 
  foreach my $nstep (@{$dep_graph->{graph}->{$step}->{nxt}}) {
    &enum_chain($nstep,$depnrref,$dep_graph,$stepsref);
  }
}

sub analyse_step_chains {
  my $self = shift;
  my($step,$sref,$dep_graph, $depstep, $chainnr, $depnr); 

  # system info, steps statistics 
  my $stepsref=$self->{STEPDEFS};

  foreach $step (keys(%{$stepsref})) {
    $sref=$stepsref->{$step};
    $sref->{chainid}="-";
    # need to be improved, multiple dependencies possible
    if(defined($sref->{exec_after})) {
      # need to be improved, multiple dependencies possible
      foreach $depstep (split(/\s*,\s*/,$sref->{exec_after})) {
        push(@{$dep_graph->{graph}->{$depstep}->{nxt}},$step);
        push(@{$dep_graph->{graph}->{$step}->{prev}},$depstep);
      }
    }
  }

  # find entry point of step chains
  my $entrystep=undef;
  foreach $step (keys(%{$dep_graph->{graph}})) {
    if ( exists($dep_graph->{graph}->{$step}->{nxt})  && (!exists($dep_graph->{graph}->{$step}->{prev}) ) ) {
      if(defined($entrystep)) {
        $msg=sprintf("[$PRIMARKER] ERROR: Found multiple entry points to execute graph: $entrystep $step! Exiting...\n"); logmsg($msg,\*STDERR);
        exit;
      }
      $entrystep=$step;
    }
  }
  if(defined($entrystep)) {
    $depnr=0;
    &enum_chain($entrystep,\$depnr,$dep_graph,$stepsref);
    $dep_graph->{entry}=$entrystep;
  } else {
    $msg=sprintf("[$PRIMARKER] ERROR: Found no entry point to execute graph! Exiting...\n"); logmsg($msg,\*STDERR);
    exit;
  }
  
  $self->{DEPGRAPH}=$dep_graph;
}

1;
