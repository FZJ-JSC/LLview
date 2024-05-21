# LLview Public Releases

### 2.3.0-base (May 21, 2024)

Faster tables! Using now ag-grid to virtualise the tables, now many more jobs can be shown on the tables. It also provides a "Quick Filter" (or Global Search) that is applied over all columns at once.

<h4> Added </h4>

- Support for datatables/grids
- CSV files can be generated 
- New template and Perl script to create grid column definitions
- Added `dc-wai` queue on jureptool system config
- JURI: Added grid (faster tables) support using [ag-grid-community](https://github.com/ag-grid/ag-grid) library 
- JURI: Helper functions for grid
- JURI: Grid filters (including custom number filter, which accepts greater '>#', lesser '<#' and InRange '#-#'; and 'clear filter' per column)
- JURI: Quick filter (on header bar)
- JURI: Now data can be loaded from csv (usually much smaller than json)

<h4> Changed </h4>

- Removed old 'render' field from column definitions (not used)
- Default Support view now has a single 'Jobs' page with running and history jobs using grid
- JURI: Adapted to grid:
    - Buttons on infoline (column groups show/hide, entries, clear filter, download csv)
    - Presentation mode
    - Refresh button
    - Link from jobs on workflows

<h4> Fixed </h4>

- Improved README and Contributing pages
- Fixed text of Light/Dark mode on documentation page
- Fixed get_cmap deprecation in new matplotlib version
- JURI: Small issues on helpers
- JURI: Fixed color on 'clear filter' link


### 2.2.4-base (April 3, 2024)

<h4> Added </h4>

- Added System tab (usage and statistics) for Support View
- Added option to delete error files on `listerrors` script
- Added `llview` controller in scripts (`llview stop` and `llview start` for now)
- Added power measurements (`CurrentWatts`) (LML, database and JuRepTool)
- Added `LLVIEW_WEB_DATA` option on `.llview_server_rc` (not hardcoded on yaml anymore, as the envvars are expanded for `post_rows`)
- Added `LLVIEW_WEB_IMAGE` option on `.llview_server_rc` to change web image file
- Added `wservice` and `execdir` automatic folder creation
- Added `.llview_server_rc` to monitor (otherwise, changes in that file required "hard" restart)
- Added `icmap` action, configuration and documentation
- Added generation of DBgraphs (from production) to automatically create dependency graphs (shown as mermaid graphs on the "Dependency Graphs" of Support View)
- Added trigger script and step to `dbupdate` action to use on DBs that need triggering
- Added options to dump options as JSON or YAML using envvars (`LLMONDB_DUMP_CONFIG_TO_JSON` and `LLMONDB_DUMP_CONFIG_TO_YAML`)
- Added `CODE_OF_CONDUCT.md`
- JURI: Added CorePattern fonts and style
- JURI: Added `.htpasswd` and OIDC examples and general improvements on `.htaccess`
- JURI: Added system selector when given on setup
- JURI: Added 'RewriteEngine on' to `.htaccess` (required for `.gz` files)
- JURI: Added buttons on fields in `login.php`
- JURI: Added home button
- JURI: Added mermaid graphs and external js
- JURI: Added svg-pan-zoom to zoom on graphs
- JURI: Added option to pass image in config
- JURI: Added "DEMO" on system name when new option `demo: true` is used

<h4> Changed </h4>

- Improved `systemname` in slurm plugin
- Changed order on `.llview_server_rc` to match  `.llview_remote_rc`
- Separated `transferreports` stat step on `dbupdate.conf`
- Moved folder creation msg to log instead of errlog
- Improved documentation about `.htaccess` and `accountmap`
- Improved column group names (now possible with special characters and space)
- Changed name "adapter" to "plugins"
- Improved parsing of envvars (that can now be empty strings) from .conf files
- Further general improvements on texts, logs, error messages and documentation
- JuRepTool: Improvements on documentation and config files
- JuRepTool: Moved config folder outside server folder
- JURI: Adapted `login.php` to handle also OIDC using REMOTE_USER
- JURI: Improved favicon
- JURI: Changed how versions of external libraries are modified (now via links, such that future versions always work with old reports)
- JURI: Updated plotly.js
- JURI: Improvements in column group names, with special characters being escaped
- JURI: Changed footer filename (as it does not include only plotly anymore)

<h4> Fixed </h4>

- Fixed `starttime=unknown`
- Fixed support in `.htgroups` when there's no PI/PA 
- Fixed `'UNLIMITED'` time in conversion
- Fixed creation of folder on SLURM plugin
- Fixed missing `id` on `<input>` element
- Removed export of `.llview_server_rc` from scripts (as it resulted in errors when in a different location)
- JuRepTool: Fixed deprecation messages
- JURI: Fix `graph_footer_plotly.handlebar` to have a common root (caused an error in Firefox)
- JURI: Fix `.pdf.gz` extension on `.htaccess` example
- JURI: Removed some anchors `href=#` as it was breaking the fragment of the page
- JURI: Fixed forwarding to job report when using jump to jobID


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

