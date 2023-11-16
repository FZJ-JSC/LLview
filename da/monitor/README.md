# DA Monitor

#### Contents

```
.
├── actions.inp
├── monitor_file.pl
├── README.md
├── RESTARTNOW_monitor
├── SHUTDOWNNOW_monitor
└── start_monitor
```

---

This directory stores the main scripts and associated files used 
to effectively executing the monitoring tasks. The main script 
that is called from the cronjob is `start_monitor`, which by itself
runs the script file `monitor_file.pl` using the configuration
file called `actions.inp` located in `$LLVIEW_CONF`.
This file describes, in an internal DA syntax, what actions must
be taken in its monitoring work.

```
perl monitor_file.pl --config "$LLVIEW_CONFIG/actions.inp"
```

The file `actions.inp` contains a set of actions that can be performed
by the script as an a reference. The basic syntax of the input file
defines a **general** section, where signals are established to make the
script aware of the current system status. This signals are themselves
files, named

* `RESTARTNOW_monitor`
* `SHUTDOWNNOW_monitor`

The next sections are **actions**, which can be meaningfully named to
allow better workflow controlling by the one defining the actions.
The keywords inside the **actions** sections are

* `active`: 1 or 0 (active or inactive)
* `watchfile`: full path of the file which holds data which is being collected
* `execute`: is a Perl script responsible to run the monitoring command (*)
* `execdir`: the directory where the monitoring script will be run
* `logfile`: the log file resulted from this monitoring process

As already mentioned, more than one *action* can be defined in the
actions file. By default the script will look for a file called
`actions.inp` if no other name is given. In order to do that
the script must be called with an argument

