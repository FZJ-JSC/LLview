# About LLview Remote

LLview Remote consists of collector plugins that run on the system to be monitored (i.e., the *remote* system). This is required as some commands are only available there. The workflow of LLview Remote is activated via cronjob to collect the metrics every minute, and put them into LML files. No LLview daemon or monitor keeps running on the system while the metrics are not being collected.

Currently, only the Slurm plugins is included, and it runs on the remote part (e.g., on a login node of the system to be monitored) to collect the reports from commands such as `scontrol` and `sacct`, by a user with permissions to get information of all jobs.
