# Troubleshooting

Here we list some problems that may occur during the installation and/or usage of LLview.

## Stuck processes

LLview uses signal files in `${LLVIEW_DATA}/${LLVIEW_SYSTEMNAME}/perm` to indicate that steps are still running.
It also checks the PID of the process is the same that initiate the process, to confirm the process is still running.
It may happen that some action fails but the process does not exit correctly, so the PID still exists.
In this case, LLview does not restart this action, which is not processed anymore.
To solve this issue, the stuck processes should be killed.
One way to check is by running `ps -ef | grep perl` to list all running Perl processes, and checking in that list the processes that are old (except `${LLVIEW_HOME}/da/monitor/monitor_file.pl`, all processes should not be older than a couple of minutes).
The files `${LLVIEW_DATA}/${LLVIEW_SYSTEMNAME}/perm/RUNNING_*` can also be removed (although they should be deleted automatically).


## Errors in DB

When modifications on the configuration of the database (that is, in the YAML files that define the database layout in `$LLVIEW_CONF/server/LLgenDB`) is done, these changes must be applied before LLview can use the new format. If that is not done, errors on DB (e.g. `DBD::SQLite::db (...)`) will be output. 

To fix this problem, the [`updatedb`](server_install.md#update) command can be run:
```
updatedb         [updates the db with output on screen]
updatedb log     [updates the db appending the output to the log file $LLVIEW_DATA/$LLVIEW_SYSTEMNAME/logs/checkDB.`date +%Y.%m.%d`.log]
updatedb viewlog [to view the logfile]
```
