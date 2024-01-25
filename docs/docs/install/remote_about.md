# About LLview Remote

LLview Remote consists of a Slurm adapter running via cronjob to collect Slurm metrics every minute, and put them into LML files. 
This must be done where commands like `scontrol` and `sacct` are available (e.g., on a login node of the system to be monitored),
and by a user with permissions to get information of all jobs.
