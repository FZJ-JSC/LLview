# Server Installation Instructions

## Dependencies

The dependencies of LLview Server are:

- Crontab
- Perl (>5) 
    - Modules (install with `cpanm <ModuleName>`)
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

## Configuration

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
- `$LLVIEW_SHARED`: A shared folder between LLview Server and [LLview Remote](remote_install.md#configuration), where the generated files from Remote will be written and read by the Server (therefore, it must be the same set up in `.llview_remote_rc` in the Remote part)
- `$LLVIEW_SHUTDOWN`: File to be used to stop LLview's workflow (the cronjob runs, but immediately stops)
- `$LLVIEW_LOG_DAYS`: Number of days to keep the logs
- `JUREPTOOL_NPROCS`: Number of processors used by JuRepTool (default: 2). As JuRepTool runs in parallel to the main LLview workflow, it is recommended to initially use `JUREPTOOL_NPROCS=0` to deactivate JuRepTool and only activate it when the full LLview cycle is working.

Extra definitions can be also exported or modules loaded in this file (for example, to satisfy the [Dependencies](#dependencies)).

### Actions

The collection and processing of data is done via actions (the first workflow level), which can contain many steps (second workflow level) each.
**It is recommended to activate actions and steps inside actions little by little**, and follow the `errlog` files, to find eventual issues and solve them as they appear.

- Edit action file `$LLVIEW_CONF/server/workflows/actions.inp` to the relevant actions to be used. It is recommended to start with `active=0` for all actions and activate them one by one.
- Edit the configuration options for each action (e.g. `$LLVIEW_CONF/server/workflows/LML_da_dbupdate.conf`), when needed. It is recommended to start all steps with `active="0"` and activate them little by little. (**Note**: a step may have dependencies that must be activated before or together with it.)
- Important reminders:
    - <a name="updatedb"></a> After making changes on the configurations that afect the databases (i.e., adding or removing tables), they must be updated. To avoid corrupting the databases or losing data, this step must be done manually. To simplify the task of updating the databases according to the new configurations, we provide the script `updatedb` in `$LLVIEW_HOME/scripts`, which can be run as:
        ```
        updatedb         [updates the db with output on screen]
        updatedb log     [updates the db appending the output to the log file $LLVIEW_DATA/$LLVIEW_SYSTEMNAME/logs/checkDB.`date +%Y.%m.%d`.log]
        updatedb viewlog [to view the logfile]
        ```
    `updatedb viewlog` can be used to check for errors (as `updatedb log` appends the output to the same log file, there may be more than one output accumulated in the same file). There is no problem running this command when the change in the configuration does not affect the databases, so it is recommended to run it after changes in the YAML files.
    - <a name="taillog"></a> To check the log and error files, we also provide a script `taillog` in `$LLVIEW_HOME/scripts` that can be used to simplify following these files with a `tail -f` command. It can be used by running
        ```
        taillog [monitor | (actionname)]
        ```
    - <a name="listerrors"></a> Another script provided in `$LLVIEW_HOME/scripts` that can be used to list all error files in the folders is `listerrors`.

#### `dbupdate` action

The `dbupdate` action mainly performs the collection of metrics into SQLite databases (plus other tasks such as archiving). The configuration of the different databases and their columns, types and values are done via the YAML files inside the `$LLVIEW_CONF/server/LLgenDB` folder.

##### `webservice` step

**This is an important step that should be edited in each installation.**

To be able to set up the role-based access of LLview (where users will have access only to their own jobs and projects, while mentors can see jobs on all mentored projects and support can see all jobs), information on the user accounts and projects are needed. This is obtained in the `webservice` step of the `dbupdate` action. In the provided example configuration, this information is generated by `$LLVIEW_HOME/da/rms/JSCinternal/get_webservice_accounts.pl` (**not-included**) that is run at every 15th update via the script `$LLVIEW_HOME/da/utils/exec_every_n_step_or_empty.pl` (included), to avoid too many connections to the database. Information about the users with support access can be obtained also via the [`supportinput` action](#supportinput-action). The output of this step should be put in the file `$LLVIEW_DATA/$LLVIEW_SYSTEMNAME/perm/wservice/accountmap.xml` that contains information to be added in the database. 

More information about how to create this file [here](accountmap.md).

#### `jobreport` action

The `jobreport` action maily creates the data to be presented to the user and copies them to the Web Server. Its configuration is also done via the YAML files inside the `$LLVIEW_CONF/server/LLgenDB` folder.

##### `transferreports` step

The `transferreports` step inside the `jobreport` action is used to transfer data securely from the LLview Server to the Web Server. To use this step as it is by default, it is necessary to create an ssh-key pair:
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

#### `supportinput` action

To set the users that have "Support" access on LLview, we use the `supportinput` action. This action watches a file (default in `${LLVIEW_SHARED}/../config/support_input.dat`) that contains a simple list of usernames (one per line). When this file is changed, the file is copied to `${LLVIEW_DATA}/${LLVIEW_SYSTEMNAME}/perm/wservice`. This file is then used in the [`webservice` step of the `dbupdate` action](#webservice-step).


#### `compress` and `archive` actions

The actions `compress` and `archive` perform actions that are created on the previous steps on the folder `${LLVIEW_DATA}/${LLVIEW_SYSTEMNAME}/tmp/jobreport/tmp/mngtactions`. They are important to keep the `${LLVIEW_DATA}/${LLVIEW_SYSTEMNAME}/tmp/jobreport/data` folder clean.

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

## Installation

- Make sure the [dependencies](#dependencies) are satisfied
- Get LLview:
    ```
    git clone https://github.com/FZJ-JSC/LLview.git
    ```
This is where the `$LLVIEW_HOME` should be defined below, and the instructions use this notation.


- Configuration:
    - **[Optional]** Copy and update config folder in `$LLVIEW_CONF` (an example is given in `$LLVIEW_HOME/configs`)
    This folder contains all the configuration files which defines the specific configuration of what is collected and what will be presented to the users.
    **Note:** The folder structure should be kept, as some scripts use `$LLVIEW_CONF/server/(...)`.
    - Edit `.llview_server_rc` (an example is given in `$LLVIEW_HOME/configs/server`) and put it in the home folder `~/`, as this is the basic configuration file and it is the only way to guarantee it is a known folder at this point. The possible options are listed [here](#llview_server_rc).
    - Edit the `$LLVIEW_CONF/LLgenDB`: here is the whole configuration of metrics, databases, etc. This can also be adapted later, but changes here may require the [`updatedb`](#updatedb) command to be run to update the databases.
- Source the main configuration file, to be able to use the variable in the next steps: 
    ```
    . ~/.llview_server_rc
    ```
- Add cronjob to crontab:
    ```
    crontab $LLVIEW_HOME/da/workflows/server/crontab/crontab.add
    ```
Check if the cronjob is added correctly:
    ```
    $ crontab -l
    # start monitor daemon
    * * * * * . ~/.llview_server_rc ; perl "$LLVIEW_HOME/da/workflows/server/crontab/serverAll.pl"
    ```

The server part of LLview involves a daemon that starts to run the first time the `serverAll.pl` script is called. Further calls will check if it is already running, and will restart it in case it is not. This script will then run the different [actions](#actions), which can be triggered in different ways (as an example, the basic [`dbupdate` action](#dbupdate-action) monitors when a signal file was changed to start the process of copying and processing the data, and then touches a signal file to trigger the [`jobreport` action](#jobreport-action)).

The monitor daemon of LLview Server can be stopped either by `touch $LLVIEW_SHUTDOWN` (this file should be defined in `.llview_server_rc`) or killing the `monitor_file.pl` process. Note that the cronjob still restarts every minute - if `$LLVIEW_SHUTDOWN` exists, the process immediately stops without starting the daemon. To remove it altogether, additionally delete/comment out the cronjob (editing with `crontab -e`).

