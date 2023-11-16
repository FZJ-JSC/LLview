# LLview Server

LLview Server is the module responsible to transfer the collected metrics (obtained by [LLview Remote](remote.md)) into SQLite3 databases, process them and send the required files to the Web Server to be presented for the user via the Jülich Reporting Interface [JURI](juri.md).

## Dependencies

The dependencies of LLview Server are:

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
- Python (>3.9) (For JuRepTool)
    - Packages (install with `pip install <PackageName>`)
        - matplotlib
        - numpy
        - pandas
        - pyyaml
        - plotly
        - cmcrameri
    - gzip (if compressed HTML are to be generated with option --gzip, python must have been installed with `gzip` capacities)
- SQLite3
- Fonts for JuRepTool
    - sans-serif: Liberation Sans or Arial
    - monospace: Liberation Mono or Courier New

## Installation Instructions

- Make sure the [Dependencies](#dependencies) are satisfied
- Get LLview:
    ```
    git clone https://github.com/FZJ-JSC/LLview.git
    ```
This is where the `$LLVIEW_HOME` should be defined below, and the instructions use this notation.


- Configuration:
    - **[Optional]** Copy and update config folder in `$LLVIEW_CONF` (an example is given in `$LLVIEW_HOME/configs`)
    This folder contains all the configuration files which defines the specific configuration of what is collected and what will be presented to the users.
    **Note:** The folder structure should be kept, as some scripts use `$LLVIEW_CONF/server/(...)`.
    - Edit `.llview_server_rc` (an example is given in `$LLVIEW_HOME/configs/server`) and put it in the home folder `~/`, as this is the basic configuration file and it is the only way to guarantee it is a known folder at this point. The possible options are [listed below](#llview_server_rc).
    - Edit the `$LLVIEW_CONF/LLgenDB`: here is the whole configuration of metrics, databases, etc. This can also be adapted later, but changes here may require the [checkDB](#checkDB) command to be run to update the databases.
- Source the main configuration file, to be able to use the variable in the next steps: 
    ```
    . ~/.llview_server_rc
    ```

LLview Server can then be stopped either by touching the `$LLVIEW_SHUTDOWN` file defined in `.llview_server_rc` (the cronjob still runs every minute, but immediately stops). To remove it altogether, additionally delete/comment out the cronjob (editing with `crontab -e`).

## Configurations

### `.llview_server_rc`

The main configuration file of LLview Server is `.llview_server_rc`, that should be put on the home folder `~`.
This file export environment variables that will be used by the different scripts of LLview.
The existing variables are:

- `$LLVIEW_SYSTEMNAME`: Defines the system name
- `$LLVIEW_HOME`: LLview's home folder, where the repo was cloned
- `$LLVIEW_DATA`: Folder in which the data will be stored. It is also possible to use another hard drive or file system (depending on the amount of metrics, this may be recommended). Either the driver is directly mounted and defined in `$LLVIEW_DATA`, or a symbolic link is created:
    ```
    ln -s /externalvolume/ $LLVIEW_DATA
    ```
- `$LLVIEW_CONF`: Folder with the configuration files (example configuration files is given in `$LLVIEW_HOME/configs`)
- `JUREPTOOL_NPROCS`: Number of processors used by JuRepTool (default: 2). As JuRepTool runs in parallel to the main LLview workflow, it is recommended to initially use `JUREPTOOL_NPROCS=0` to deactivate JuRepTool and only activate it when the full LLview cycle is working.
- `$LLVIEW_SHARED`: A shared folder between LLview Server and [LLview Remote](remote.md), where the generated files from Remote will be written and read by the Server (therefore, it must be the same set up in `.llview_remote_rc` in the Remote part)
- `$LLVIEW_SHUTDOWN`: File to be used to stop LLview's workflow (the cronjob runs, but immediately stops)
- `$LLVIEW_LOG_DAYS`: Number of days to keep the logs

Extra definitions can be also exported in this file (for example, to satisfy the [Dependencies](index.md#software-dependencies)).

### Actions

The collection and processing of data is done via actions (the first workflow level), which can contain many steps (second workflow level) each.
It is recommended to activate actions and steps inside actions one by one, and follow the `errlog` files, to find eventual issues and solve them one by one.

- Edit action file `$LLVIEW_CONF/server/workflows/actions.inp` to the relevant actions to be used. It is recommended to start with `active=0` for all actions and activate them one by one.
- Edit the configuration options for each action (e.g. `$LLVIEW_CONF/server/workflows/LML_da_dbupdate.conf`), when needed. It is recommended to start all steps with `active="0"` and activate them little by little. (**Note**: a step may have dependencies and must be activated before or together with others.)
- The `dbupdate` action mainly performs the collection of metrics into SQLite databases (plus other tasks such as archiving). The configuration of the different databases and their columns, types and values are done via the YAML files inside the `$LLVIEW_CONF/server/LLgenDB` folder.
- The `jobreport` action maily creates the data to be presented to the user and copies them to the Web Server. Its configuration is also done via the YAML files inside the `$LLVIEW_CONF/server/LLgenDB` folder.
- Important reminders:
    - <a name="checkDB"></a> Before activating the `LMLDBupdate.pl` step of the `dbupdate` workflow, the corresponding databases must be created. This can done via a `checkDB` command:
        ```
        . ~/.llview_server_rc; cd $LLVIEW_DATA/$LLVIEW_SYSTEMNAME;
        $LLVIEW_HOME/da/LLmonDB/LLmonDB_mngt.pl -config=$LLVIEW_CONF/server/LLgenDB/LLgenDB.yaml --force checkDB > logs/checkDBv1.`date +%Y.%m.%d`.log 2>&1
        ```
    The file ```logs/checkDBv1.`date +%Y.%m.%d`.log``` can then be checked for errors.
    This command should be run every time the database is changed in the YAML configuration files (new tables are added or removed, etc.). It updates the database to be used by LLview.
    - <a name="transferreports"></a> The `transferreports` step inside the `jobreport` action is used to transfer data securely from the LLview Server to the Web Server. To use this step as it is by default, it is necessary to create an ssh-key pair:
        ```
        cd $LLVIEW_DATA/$SYSTEMNAME/perm/
        mkdir keys
        cd keys
        ssh-keygen -a 100 -t ed25519 -C ‘LLview job report transport from LLview-Server’ -f www_llview_system_jobreport
        ```
    This must be created without any passphrase.
    Then, on the Web Server, the public part of the key must be added in `~/.ssh/authorized_keys` as:
        ```
        from="<ip of LLview server>",command="<path to rrsync>/rrsync.pl -wo <folder where data will be copied into>",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding <complete public part of the ssh-key>
        ```
    **Note:** the line above must be adapted to include the correct IP where the LLview Server part is running, the path to `rrsync.pl` on the web server (this tool is packed with JURI in the folder `$JURI_HOME/utils`), and the public part of the key created above.
    Finally, the command itself must be updated with the correct values for:
        ```            
        -sshkey $permdir/keys/www_llview_system_jobreport
        -login <login on the web server>
        -port <port used>
        -desthost <webserver address>
        ```
    **Note:** An initial login may be needed to accept the authenticity of the host (`ssh <login>@<webserver address>` and then `yes` is enough, even if you get "Permission denied" afterwards)

### JuRepTool

JuRepTool is the LLview module that generates the PDF and HTML reports. It runs in parallel alongside LLview's main workflow, and the generated files are automatically copied and made available on the LLview portal.
To setup and use JuRepTool:

- Update the config files located under `$LLVIEW_CONF/server/jureptool`. The configuration of the script and plots are given in 4 YAML files:
    - `config.yml`: General configuration such as fontsize, page size, colors, etc. (env vars can be used here)
    - `system_info.yml`: Information on the system names, queues and sizes (cores, CPU and GPU memory)
    - `plots.yml`: Configuration of sections and the graphs to be plotted in each of them. Keywords from `system_info.yml` may be used in `ylim`.
    - `logging.yml`: Logging information (filename, format, level)
- Add required fonts (Liberation Sans or Arial, Liberation Mono or Courier New). Liberation fonts are Open Source and can be downloaded from [Liberation Fonts' GitHub](https://github.com/liberationfonts/liberation-fonts/releases).
Fonts can be installed with:
    ```
    mkdir ~/.local/share/fonts/
    cp <fonts_folder>/*.ttf ~/.local/share/fonts/
    fc-cache -f
    rm -fr ~/.cache/matplotlib
    ```
- Give a non-zero value for the number of processes to be used by JuRepTool via the variable `$JUREPTOOL_NPROCS` in `.llview_server_rc`.

## Folder Structure

The generated files are put into the folder defined in `$LLVIEW_DATA/$LLVIEW_SYSTEMNAME`.
The subfolders that used for the default steps are:

- `monitor`: Location of the log files for the main monitor script (that is run by the cronjob)
- `logs`: Location of the log files
    - `steps`: Folder storing temporary log files for each step of all actions that are created and overwritten during every cycle and also permanent error files that happen during the steps
- `perm`: Folder used by LLview to store files indicating a job is running, counters
    - `db`: Folder where SQLite databases are located
    - `keys`: Where SSH-keys for the [transferreports](#transferreports) step are stored
    - `wservice`: Store the mapping of the Web Service accounts
- `tmp`: Location of the temporary LML files (e.g., the ones copied from `$LLVIEW_SHARED`)
    - `jobreport`: Files generated by the `jobreport` action
        - `data`: Folder that is copied to the Web Server
        - `tmp`: Contains the list of jobs JuRepTool needs to process and management files
- `arch`: Location of the archived files
    - `db`: csv files containing DB information
    - `LMLall`: Daily tarballs containing combined information of jobs
- `jureptool`: Folder used for temporary JuRepTool files and also location of default `shutdown` file (that stops only JuRepTool)
    - `results`: Where reports are first generated, and then moved to their final location (to avoid problems during copy to the Web Server)
