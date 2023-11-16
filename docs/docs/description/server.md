The server part of LLview is started using `checkAll.pl` script added to crontab of the LLview server.
This cronjob is run every minute.
Examples are provided in `${LLVIEW_HOME}/da/workflows/crontab/`, and the folder is linked to `${HOME}/crontab` for simplicity (i.e., `ln -s ${LLVIEW_HOME}/da/workflows/crontab/system ${HOME}/crontab`).
The main job of `checkAll.pl` is to check if the monitor is running, and if not, start it (other tasks can be done here, such as selecting `mmpmon` output and running [JuRepTool](JuRepTool) in parallel).
This task can be done via a separate script (for example, `${LLVIEW_HOME}/da/workflows/monitor/start_monitor`, as done in the past) or directly via a command to call the monitor script.

!!! important

    The main script `checkAll.pl` uses a signal file `${HOME}/HALT_ALL` (configurable) to interrupt the periodic restart of LLview Server. This is used to completely stop LLview, for example, during maintenances.


## `monitor_file.pl`

The monitor script that runs from the `checkAll.pl` script is `${LLVIEW_HOME}/da/monitor/monitor_file.pl`, which accepts a configuration file with all the actions that must be done on the server. 
[The script is run from `${LLVIEW_DATA}/system/monitor`, where the log and error files of the monitor are located.]
The action files are located in `${LLVIEW_CONF}/actions.inp`.

The "actions" configuration file defines first signal files for restarting the monitor, the deamon or to stop it altogether:

!!! note

    It is possible to use environment variables within the configuration of the actions.


```
[General]
auto_shutdown=1
shutdown_signal_file=${HOME}/HALT_ALL
```


Many actions can then be defined on this file.
Some of them are **required** for LLview to work, others are add-ons, to include additional metrics or files.

The configuration of each step includes the following:

* `[name]`: a name for the workflow must be given between square brackets at the top;
* `active`: this key has a boolean value (0 or 1) to give a simple form to activate or deactivate that given action;
* `watchfile`: a file that, when modified, triggers the action;
* `execute`: script or executable that will be run;
* `execdir`: the folder from which the action will be run;
* `logfile`: file to which the output will be forwarded.

The actions are divided generally into workflows (mostly from historical reasons), which can be checked with a script called `taillog.sh`.

!!! note

    The monitoring actions can run in parallel, as long as their requirements (i.e., their watchfiles) are fulfilled.

## Actions

### Workflow 2

One example of a first action that is **required** is the following:

```
# Workflow part 2: color+usage+archive LMLraw
[part2]
active=1
watchfile=${LLVIEW_SHARED}/remote/system_datafiles.xml.ready
execute=${LLVIEW_HOME}/da/workflows/system/server/runLMLDA_part2
execdir=${LLVIEW_DATA}/system
logfile=${LLVIEW_DATA}/monitor/monitor_system_p2.log
```

This workflow is started when the file `${LLVIEW_SHARED}/remote/system_datafiles.xml.ready` is modified/touched by [remote](#remote). This is done when the metrics are ready to be consumed by the LLview server part. When that happens, the script `${LLVIEW_HOME}/da/workflows/system/server/runLMLDA_part2` is executed from the directory `${LLVIEW_DATA}/system`, and the log (output of `monitor_file.pl` itself) written to `${LLVIEW_DATA}/monitor/monitor_system_p2.log`.

The script `runLMLDA_part2` is actually a short and condensed form to call:
```
${LLVIEW_HOME}/da/LML_da.pl -par -nostep -conf ${LLVIEW_HOME}/da/workflows/system/server/LML_da_system_db_part2.conf >> log/p2log`date +.%Y.%m.%d` 2>> log/p2errlog`date +.%Y.%m.%d`
```
As `monitor_file.pl`, the script `${LLVIEW_HOME}/da/LML_da.pl` is another generic script of LLview that runs subtasks defined in a configuration file. In this case, the configuration is given in `${LLVIEW_HOME}/da/workflows/system/server/LML_da_system_db_part2.conf`, which is an XML-like file of the form:
```
<LML_da_workflow>
  <vardefs>
    <var key="key"         value="value"/>
    (...)
  </vardefs>

  <step active="1" id="start" exec_after="" type="execute">
    (...)
  </step>

  <step active="1" id="step2" exec_after="start" type="execute">
    (...)
  </step>

</LML_da_workflow>
```
Variables can be defined in the first section, `<vardefs>`, to simplify their usage later on (to define common directories or files, for example). In the example above, the variable `$key` can be used on the steps below, and is substituted by `value`.



### Workflow 2map

```
# Workflow part 2map of Juwels-Booster: copying of support list for mapping
[action_jwb2map]
active=1
watchfile=/p/hpcmon/JURECA/llstat/config/support_input.dat
execute="cp /p/hpcmon/JURECA/llstat/config/support_input.dat ./"
execdir=/home/llstat/.data/juwels_booster/perm/wservice
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p2map.log
```

### Workflow 2rc

```
# Workflow part 2rc of Juwels-Booster: handling of job return codes
[action_jwb2rc]
active=1
watchfile=/p/hpcmon/JUWELS/llstat/remote_booster/jobs_rc_LML.xml.ready
execute=/home/llstat/llview/da/workflows/juwels_booster/server/runLMLDA_part2rc
execdir=/home/llstat/.data/juwels_booster
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p2rc.log
```

### Workflow 2icmap

```
# Workflow part 2icmap of Juwels-Booster: handling of system IC mapping file
[action_jwb2icmap]
active=1
watchfile=/home/llstat/.data/juwels_booster/perm/jureca_JRC.map
execute=/home/llstat/llview/da/workflows/juwels_booster/server/runLMLDA_part2icmap
execdir=/home/llstat/.data/juwels_booster
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p2icmap.log


# Workflow part 2step of Juwels-Booster: handling of job step info
[action_jwb2step]
active=1
watchfile=/p/hpcmon/JUWELS/llstat/remote_booster/jobs_step_LML.xml.ready
execute=/home/llstat/llview/da/workflows/juwels_booster/server/runLMLDA_part2step
execdir=/home/llstat/.data/juwels_booster
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p2step.log

# Workflow part 2checkmk of Juwels-Booster:  (get result from other server)
[action_jwb2checkmk]
active=1
watchfile=/p/hpcmon/JUWELS/llstat/server_booster/juwels_booster_cmk_values.csv
execute=/home/llstat/llview/da/workflows/juwels_booster/server/runLMLDA_part2checkmk
execdir=/home/llstat/.data/juwels_booster
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p2checkmk.log

#
# Workflow part 3 of Juwels-Booster: rest of workflow, incl. transfer to web server
[action_jwb3]
active=1
watchfile=/home/llstat/.data/juwels_booster/perm/lmlstat_start_ready
execute=/home/llstat/llview/da/workflows/juwels_booster/server/runLMLDA_part3
execdir=/home/llstat/.data/juwels_booster
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p3.log

# Workflow part 3 of Juwels-Booster: jufo batch (put input to other server)
[action_jwb3jufocp]
active=1
watchfile=/home/llstat/.data/juwels_booster/perm/JUWELS_BOOSTER_system_state_color_LML.xml.ready
execute="cp -p /home/llstat/.data/juwels_booster/perm/JUWELS_BOOSTER_system_state_color_LML.xml /p/hpcmon/JUWELS/llstat/server_booster2/; touch /p/hpcmon/JUWELS/llstat/server_booster2/JUWELS_BOOSTER_system_state_color_LML.xml.ready"
execdir=/home/llstat/.data/juwels_booster/perm/
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p3jufocp.log

# Workflow part 4 of Juwels-Booster: jobreport
[action_jwb4]
active=1
watchfile=/home/llstat/.data/juwels_booster/perm/jobreport_start_ready
execute=/home/llstat/llview/da/workflows/juwels_booster/server/runLMLDA_part4
execdir=/home/llstat/.data/juwels_booster
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p4.log


# Workflow part 4actions of Juwels-Booster: perform delayed action on jobreport files (compress)
[action_jwb4comp]
active=1
watchfile=/home/llstat/.data/juwels_booster/tmp/jobreport/tmp/mngtactions/mngt_actions_compress_lastts.dat
execute=/home/llstat/llview/da/workflows/juwels_booster/server/runLMLDA_part4actcomp
execdir=/home/llstat/.data/juwels_booster
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p4actcomp.log

# Workflow part 4actions of Juwels-Booster: perform delayed action on jobreport files (archive)
[action_jwb4tar]
active=1
watchfile=/home/llstat/.data/juwels_booster/tmp/jobreport/tmp/mngtactions/mngt_actions_tar_lastts.dat
execute=/home/llstat/llview/da/workflows/juwels_booster/server/runLMLDA_part4acttar
execdir=/home/llstat/.data/juwels_booster
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p4acttar.log

#
# Workflow part 5 of Juwels-Booster: jufo batch (get result from other server)
[action_jwb5jufocp]
active=1
watchfile=/p/hpcmon/JUWELS/llstat/server_booster2/LMLraw_juwels_booster_jufo_batch_gen.list.ready
execute="cp /p/hpcmon/JUWELS/llstat/server_booster2/LMLraw_juwels_booster_jufo_batch_gen.list ./"
execdir=/home/llstat/.data/juwels_booster/tmp
logfile=/home/llstat/.data/monitor/monitor_juwels_booster_p5jufocp.log
```
