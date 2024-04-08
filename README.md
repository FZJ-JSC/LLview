<div align="left">
  <img src="docs/docs/images/LLview_logo.svg" alt="LLview" height="150em"/>
</div>

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.10221407.svg)](https://doi.org/10.5281/zenodo.10221407)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

# LLview

LLview is a set of software components to monitor clusters that are controlled by a resource manager and a scheduler system. Within its Job Reporting module, it provides detailed information of all the individual jobs running on the system. To achieve this, LLview connects to different sources in the system and collects data to present to the user via a web portal. For example, the resource manager provides information about the jobs, while additional daemons may be used to acquire extra information from the compute nodes, keeping the overhead at a minimum, as the metrics are obtained in the range of minutes apart. The LLview portal establishes a link between performance metrics and individual jobs to provide a comprehensive job reporting interface.

## Installation

Installation instructions can be found on LLview's [documentation page](https://apps.fz-juelich.de/jsc/llview/docu/install/).

LLview presents its gathered data in a Web Portal created by [JURI](https://github.com/FZJ-JSC/JURI).

## Further Information

For further information please see: http://www.fz-juelich.de/jsc/llview

Contact: [llview.jsc@fz-juelich.de](mailto:llview.jsc@fz-juelich.de)

## Copyright, License and CLA

Copyright (c) 2023 Forschungszentrum Juelich GmbH, Juelich Supercomputing Centre  
http://llview.fz-juelich.de/

This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.

Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
