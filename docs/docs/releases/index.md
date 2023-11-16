# Releases

## Version 2.1

LLview got constant updates in the last months. Apart from the general improvements, an important recent adition was the inclusion of new [core usage metrics](../jobreport/metrics_list.md). New values are added to the tables of active and finished jobs, graphs were added to the footer when a job is selected (including a new footer tab `Cores`), and new graphs were added to the PDF and HTML reports. 

The new metrics can help users, admins and support staff to find wrong configuration or pinning on jobs - as discussed in [this example](../jobreport/examples.md#high-cpu-load-with-low-cpu-usage).

Full Changelog:

* Added IOI information (DEEP-only)
* Increased max_entries per table to 5000
* Fixed wrong 1M factor on Open/Close operations
* Improved display of "wait time" and "walltime" to hh:mm
* Fixed missing steps and stuck "Running" state
* Improved "Comments" and "Job Names" collection 
* Improved REASON annotations on footer graph of Queued jobs
* Added column "Reservation" on the tables of the Job Reporting portal
* Added more information when hovering on each step of the timeline on HTML reports
* Added Queue Date and Wait Time to the PDF and HTML reports
* Added Slurm script to PDF and HTML reports
* Added more internal information: LLview usage, Step timings, complexity, timelines, statistics, usage histograms (Support View only)
* Added new pages and graph pages for System Information: IO, Fabric, Environment, Overview (Support View only)
* Added Core usage metrics, including new columns and footer graphs on Job Reporting portal, and new graphs on PDF and HTML reports
* Improved table column names and descriptions
* Total score use now CPU Usage instead of CPU Load
* Added Workflow Manager information (DEEP-only)
* Added GPU information from DCDB (DEEP-only)
* `CANCELLED by <id>` is now shown as `CANCELLED by <username>`
* Internal fixes and improvements

## Version 2.0

The new version of LLview, released in the end of 2022, has many new features.
Besides a major internal restructure - the kernel of LLview was completely re-written - and a redesign of the page, here are some of the new features:

### General

* Easier to configure, generalise and add new and aggregated metrics
* More stable updates, with less missing points
* Improved values for `Interconnect` metrics

### Web portal

* Workflow tab, currently containing information about SLURM workflows (chains and arrays)
* Improved bottom graphs when selecting a job
* Option to change the colorscale on the job tables
* Auto-refresh button on the top right of LLview web portal
* System information and graphs `(available for support and admins)`
* Internal monitoring of LLview database and timings `(available for support and admins)`
* Searching for a job ID will search all running and history `(available for support and admins)`

### Detailed reports

* Option to change the colorscale (colors and limits) on interactive reports
* Timeline on the detailed reports (both interactive and PDF)
* Click-to-focus Timeline: on the interactive reports, clicking on a step changes the time-interval to the respective range
* Improved zoom-lock, that can be controled also from the interactive timeline
