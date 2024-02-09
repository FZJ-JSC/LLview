# About LLview Server

LLview Server is the module responsible to transfer the collected metrics (obtained by [LLview Remote](remote_about.md)) into SQLite3 databases, process them and send the required files to the Web Server to be presented for the user via the Jülich Reporting Interface [JURI](juri_about.md).

LLview Server works as a daemon that keeps running and monitoring conditions to run **actions**. Triggers for these actions can be: modifications in files, interval of time, or a fixed second on the minute.