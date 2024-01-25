# LLview Installation Instructions

## Dependencies

The dependencies of LLview Remote are:

- Crontab
- Perl (>5) 
    - Modules (install with `cpan <ModuleName>`)
        - Data::Dumper
        - Getopt::Long
        - Time::Local
        - Time::HiRes
        - FindBin
        - Parallel::ForkManager
        - File::Monitor
        - File::Spec
        - Exporter
        - Storable
        - IO::File
        - POSIX
        - YAML::XS
        - DBI
        - DBD::SQLite
        - Config::IniFiles
        - JSON
- Python (>3.9) (For the Slurm adapter)

## Configuration

### `.llview_remote_rc`

The main configuration file of LLview Remote is `.llview_remote_rc`, that should be put on the home folder `~`.
This file export environment variables that will be used by the different scripts of LLview.
The existing variables are:

- `$LLVIEW_SYSTEMNAME`: Defines the system name
- `$LLVIEW_HOME`: LLview's home folder, where the repo was cloned
- `$LLVIEW_DATA`: Folder in which the data will be stored
- `$LLVIEW_CONF`: Folder with the configuration files (example configuration files is given in `$LLVIEW_HOME/configs`)
- `$LLVIEW_SHARED`: A shared folder between LLview Remote and [LLview Server](server_install.md#configuration), where the generated files from Remote will be written and read by the Server (therefore, it must be the same set up in `.llview_server_rc` in the Server part)
- `$LLVIEW_SHUTDOWN`: File to be used to stop LLview's workflow (the cronjob runs, but immediately stops)
- `$LLVIEW_LOG_DAYS`: Number of days to keep the logs

Extra definitions can be also exported in this file (for example, to satisfy the [dependencies](#dependencies)).


## Installation

- Make sure the [dependencies](#dependencies) are satisfied.
- Get LLview:
    ```
    git clone https://github.com/FZJ-JSC/LLview.git
    ```
This is where the `$LLVIEW_HOME` should be defined below, and the instructions use this notation.
- Configure:
    - **[Optional]** Copy the config folder `$LLVIEW_HOME/configs` outside the repo. 
    This folder contains all the configuration files which defines the specific configuration of what is collected and what will be presented to the users.
    **Note:** The folder structure should be kept, as some scripts use `$LLVIEW_CONF/remote/(...)`.
    - Edit `.llview_remote_rc` (an example is given in `$LLVIEW_HOME/configs/remote`) and put it in the home folder `~/`, as this is the basic configuration file and it is the only way to guarantee it is a known folder at this point. The possible options are listed [here](#llview_remote_rc).
    - **[Optional]** Check configuration of Slurm adapter on `$LLVIEW_CONF/remote/adapters/slurm.yml` (`$LLVIEW_CONF` is the configuration folder defined in `.llview_remote_rc`). The default configuration should work out-of-the-box.
- Add cronjob to crontab:
    ```
    crontab $LLVIEW_HOME/da/workflows/remote/crontab/crontab.add
    ```
Check if the cronjob is added correctly:
    ```
    $ crontab -l
    * * * * * . ~/.llview_remote_rc ; perl "$LLVIEW_HOME/da/workflows/remote/crontab/remoteAll.pl"
    ```

The Remote part of LLview runs the collection of data every minute. This means that there's no daemon that keeps running on the system.
This automatic workflow can then be stopped either by removing/commenting out the cronjob (editing with `crontab -e`), or touching the `$LLVIEW_SHUTDOWN` file defined in `.llview_remote_rc`. In the latter case, the scripts still run, but they stop immediately.

