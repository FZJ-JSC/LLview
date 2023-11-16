The remote part runs on the system to be monitored, where LLview can collect the metrics.
The main building blocks of this part are the _adapters_, which are scripts that gather values from a given source and prepare [LML Files](../#lml-files).

The gathering of data is run every minute via crontab (using the schedule `* * * * *`).
A file to be added to the crontab is given in `${LLVIEW_HOME}/da/workflows/<system>/remote/crontab.add` (can be added with `crontab <file>`).
It includes also a regular cleaning of the log files: the logs are weekly moved to `*log_<date>` files, and these are deleted on the week after.

