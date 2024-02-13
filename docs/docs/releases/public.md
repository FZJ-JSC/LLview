# LLview Public Releases

### 2.2.3-base (February 13, 2024)

<h4> Added </h4>

- Added [script to convert account mapping from CSV to XML](../install/accountmap.md#csv-format)
- Slurm adapter: Added 'UNKNOWN+MAINTENANCE' state
- Added link to project in Project tab
- Added helper scripts in `$LLVIEW_HOME/scripts` folder and added this folder in PATH
- JURI: Added CorePattern fonts and style

<h4> Changed </h4>

- Added more debug information
- Further improved [installations instructions](../install/index.md)
- Slurm adapter: Removed hardcoded way to give system name and added to options in yaml
- Removed error msg from hhmm_short and hhmmss_short, as they can have values that can't be converted (e.g: wall can also have 'UNLIMITED' argument)
- JuRepTool: Changed log file extension
- JURI: Changed how versions of external libraries are modified (now via links, such that future versions always work with old reports)
- JURI: Removed old plotly library
- JURI: Changed login.php to use REMOTE_USER (compatible with OIDC too)
- JURI: Improved favicon SVG

<h4> Fixed </h4>

- Fixed wall default
- Removed jobs from root and admin also from plotlist.dat (to avoid errors on JuRepTool)
- fixed SQL type for perc_t
- JuRepTool: Fixed loglevel from command line
- JuRepTool: Improved parsing of (key,value) pairs
- JuRepTool: Fixed favicon 
- JuRepTool: Fixed timeline zoom sync
- JuRepTool/JURI: Removed external js libraries versions
- JURI: Fix graph_footer_plotly.handlebar to have a common root (to avoid xml error)
- JURI: Fix .pdf.gz extension on .htaccess


### 2.2.2-base (January 16, 2024)

<h4> Added </h4>

- Added link to JURI on README
- Added [troubleshooting](../install/troubleshooting.md) page on docs
- Added [description of step `webservice` on the `dbupdate`](../install/server_install.md#webservice-step) action
- Added timings in Slurm adapter's LML
- Added new queue on JuRepTool
- Possibility to use more than one helper function via `data_pre` (from right to left)
- Core pattern example configuration (when information of usage per core is available)
- Added info button on the top right when a page has a 'description' attribute (JURI)

<h4> Changed </h4>

- Changed images on Web Portal to svg
- Improved [installations instructions](../install/index.md)
- Lock PR after merge (CLA action)
- Improved CITATIONS.cff
- Automatically create shareddir in remote Slurm action
- Changed name of crontab logs (to avoid problems in case remote and server run on the same place)
- Improve footer resize (JURI)
- Implemented suggestions from Lighthouse for better accessibility (JURI)
- Colorscales improved, and changed default to RdYlGr (JURI)

<h4> Fixed </h4>

- Fixed default values of wall, waittime, timetostart, and rc_wallh
- Improved how logs are cleaned to avoid stuck files
- Fixed workflow of jobs with a single step


### 2.2.1-base (November 29, 2023)

<h4> Added </h4>

- Added Presentation mode (JURI)

<h4> Changed </h4>

- Improved the parsing of values from LML to database

<h4> Fixed </h4>

- Added missing example configuration files


### 2.2.0-base (November 13, 2023)

A new package of the new version of LLview was released Open Source on [GitHub](https://github.com/FZJ-JSC/LLview)!
Although it does not include all the features of the production version of LLview running internally on the JSC systems, it contains all recent updates of version 2.2.0.
On top of that, it was created using a consistent framework collecting all the configurations into few places as possible.

The included features are:

- Slurm adapter (used to collect metrics from Slurm on the system to be monitored)
- The main LLview monitor system that collects and processes the metrics into SQLite3 databases
- JuRepTool, the module to generate HTML and PDF reports
- Example actions and configurations to perform a full workflow of LLview, including:
	- collection of metrics
	- processing metrics
	- compressing and archiving
	- transfer of data to Web Server
	- presenting metrics to the users
- Jülich Reporting Interface (downloaded separately [here](https://github.com/FZJ-JSC/JURI)), the module to create the portal and present the data to the users

Not included are:

- Client (Live view)
- Other adapters (currently only Slurm)

The documentation page was also updated to include the [installation instructions](../install/index.md).

