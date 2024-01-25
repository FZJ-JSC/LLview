# Remote Folder Structure

The generated files are put into the folder defined in `$LLVIEW_DATA/$LLVIEW_SYSTEMNAME`.
Three subfolders are then used:

- `logs`: Location of the log files
- `perm`: Folder used by LLview to store files indicating a job is running
- `tmp`: Location of the temporary LML files, that will also be copied to `$LLVIEW_SHARED`
