# DA Monitor

#### Contents

```
.
├── monitor_file.pl
├── README.md
├── RESTARTNOW_monitor
└── SHUTDOWNNOW_monitor
```

---

The script `monitor_file.pl` uses a configuration file (f.ex. `actions.inp`) in ini format (https://metacpan.org/pod/Config::IniFiles).
The monitor can run commands (actions) defined in the configuration based on triggers such as time intervals and file changes.
It also restarts itself if the configuration file changes.

```
perl monitor_file.pl --config "$LLVIEW_CONFIG/actions.inp"
```

The file `actions.inp` contains a set of actions. The action **general** defines the
behaviour of the monitor itself. Comonly we define files that act as signals such as

* `RESTARTNOW_monitor`
* `SHUTDOWNNOW_monitor`

Touching these files will trigger the associated actions (aka shutdown, start, restart).
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

