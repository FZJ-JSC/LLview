---
hide:
  - navigation
---
# Known issues

## Current issues

Here we list the known issues on LLview.

### Metrics on DEEP

Not [all metrics](../jobreport/metrics_list.md) are available yet on the DEEP system. 
However, as DEEP also works as a test system for new implementations within projects,
some metrics can be available only on DEEP and not listed on the documentation.


### Incorrect display in small devices

LLview was designed to work on desktops, and issues may show up when using small devices such as smartphones. We plan to improve the LLview display on these devices in the future.

## Fixed issues

### Open/Close operations

The number of `Open/Close operations` on the detailed reports (both PDF and HTML) were a factor 1000000 (one million) too small. 
This issue was fixed on 10.02.2023 around 17:00.
