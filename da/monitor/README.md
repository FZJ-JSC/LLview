# DA Monitor

#### Contents

```
.
├── monitor_file.pl
└── README.md
```

---

The script `monitor_file.pl` uses a configuration file (f.ex. `actions.inp`) in ini format (https://metacpan.org/pod/Config::IniFiles).
By default the script will look for a file called `actions.inp` if no other name is given. In order to do that the script must be called with an argument `--config <config_file>`.
The monitor can run commands (actions) defined in the configuration based on triggers such as time intervals and file changes.
It also restarts itself if the configuration file changes.

```
perl monitor_file.pl --config "$LLVIEW_CONFIG/actions.inp"
```

The file `actions.inp` contains a set of actions. The action **general** defines the
behaviour of the monitor itself. Currently, the only available options are

* `auto_shutdown`: Turns on or off the monitoring of the shutdown file (defined below)
* `shutdown_signal_file`: Defines what is the shutdown file to be monitored. Modifications on this file (or a simple `touch`) will trigger the monitor to stop. Default: `${LLVIEW_SHUTDOWN}`, which is defined in `.llview_server_rc`

The next sections are **actions**, which can be meaningfully named to
allow better workflow controlling by the one defining the actions.
The keywords inside the **actions** sections are

* `active`: 1 or 0 (active or inactive)
* `watchfile` (trigger): full path of the file to be monitored to trigger the current action
* `watchtime` (trigger): defined second (between 0 and 59) when this action will be run (every minute)
* `interval` (trigger): inverval of time between consecutive runs of this action
* `execute`: command to be executed on this action
* `execdir`: the directory where the monitoring script will be run from
* `logfile`: the log file resulted from this monitoring process

Only a single trigger (`watchfile`, `watchtime`, or `interval`) should be given per action.
As already mentioned, more than one *action* can be defined in the actions file, and they
will be run in parallel.

