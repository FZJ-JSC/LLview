# LLview Public Releases

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

The documentation page was also updated to include the [installation instructions](../install).

