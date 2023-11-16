---
hide:
  - toc
---
<h1 align="center">Welcome to the LLview Documentation</h1>

<figure markdown>
  ![LLview Job Reporting interface](images/intro.png#only-light){ width="600" }
  ![LLview Job Reporting interface](images/intro_whitelogo.png#only-dark){ width="600" }
</figure>

LLview is a set of software components to monitor clusters that are controlled by a resource manager and a scheduler system.
It collects previously existing data from the system, and presents it to the user via a web portal. 
As an example, the resource manager itself can provide information that are available directly from the login nodes; the same applies to performance metrics about the file system that are stored in a central location. 
Additional daemons may be used to gather extra information from the compute nodes, keeping the overhead at a minimum, as the metrics are acquired in the range of minutes apart. 
With the additional data sources, the LLview portal establishes a link between performance metrics and individual jobs to provide a comprehensive job reporting interface.