# How to generate `accountmap.xml`

## XML-format

The file `accountmap.xml`, that is generated on the [`webservice` step of the `dbupdate` action](server_install.md#webservice-step), contains the information of the system accounts, their roles and which projects they should have access to. This information is used to generate the folders and `.htaccess` for the correct setting of permissions.

A mockup example of this file is the following:
```
<?xml version="1.0" encoding="UTF-8"?>
<lml:lgui>
  <objects>
    <object id="M1" name="username1" type="mentormap"/>
    <object id="M2" name="username2" type="mentormap"/>
    <object id="Q1" name="username1_L" type="pipamap"/>
    <object id="Q2" name="username3_A" type="pipamap"/>
    <object id="Q3" name="username3_L" type="pipamap"/>
    <object id="U1" name="username1" type="usermap"/>
    <object id="U2" name="username3" type="usermap"/>
    <object id="S1" name="username1" type="supportmap"/>
  </objects>
  <information>
    <info oid="M1" type="short">
      <data key="id" value="username1"/>
      <data key="projects" value="project1,project2"/>
      <data key="ts" value="1705592470"/>
      <data key="wsaccount" value="username1"/>
    <info oid="M2" type="short">
      <data key="id" value="username2"/>
      <data key="projects" value="project3"/>
      <data key="ts" value="1705592470"/>
      <data key="wsaccount" value="username2"/>
    </info>
    <info oid="P1" type="short">
      <data key="id" value="username1"/>
      <data key="projects" value="project1"/>
      <data key="ts" value="1705592470"/>
      <data key="wsaccount" value="username1"/>
      <data key="kind" value="L"/>
    <info oid="P2" type="short">
      <data key="id" value="username3"/>
      <data key="projects" value="project1"/>
      <data key="ts" value="1705592470"/>
      <data key="wsaccount" value="username3"/>
      <data key="kind" value="A"/>
    <info oid="P3" type="short">
      <data key="id" value="username3"/>
      <data key="projects" value="project2,project3"/>
      <data key="ts" value="1705592470"/>
      <data key="wsaccount" value="username3"/>
      <data key="kind" value="L"/>
    </info>
    <info oid="U1" type="short">
      <data key="id" value="username1"/>
      <data key="projects" value="project1,project2,project3"/>
      <data key="ts" value="1705592470"/>
      <data key="wsaccount" value="username1"/>
    <info oid="U2" type="short">
      <data key="id" value="username3"/>
      <data key="projects" value="project1,project2,project3"/>
      <data key="ts" value="1705592470"/>
      <data key="wsaccount" value="username3"/>
    </info>
    <info oid="S1" type="short">
      <data key="id" value="username1"/>
      <data key="ts" value="1705592470"/>
      <data key="wsaccount" value="username1"/>
    </info>
  </information>
</lml:lgui>
```

This example includes:

* Two mentors:
    * `username1` is a mentor of projects `project1,project2`
    * `username2` is a mentor of project `project3`
* Two PIs:
    * `username1` is the leader of project `project1`
    * `username3` is the leader of projects `project2,project3`
* One PA:
    * `username3` is the administrator of project `project1`
* One support:
    * `username1` belongs to the support staff
* Two users:
    * `username1` is a user of projects `project1,project2,project3`
    * `username3` is a user of project `project3`

Notes:

* It is important that the object `id` in the list of objects to be the same as the `oid` in the `<info>` element that defines it below.
* To avoid duplication of names in the objects, we add the suffixes `_L` and `_A` to the usernames for the Principal Investigator (PI), i.e., the leader of a project and Project Administrator (PA), respectively. These letters are also passed as the value of the keys `kind` inside the respective `<info>` element.
* The key `wsaccount` should contain the user name used to login to the web service.
* The groups can have overlap, i.e., a user can be support, mentor, PI/PA and user of a project.
* A user does not need to be defined in all places. In particular, they can be from support and/or mentor, but not be part of any project.
* The `ts` key should include the timestamp the data was acquired.
* Identation is not necessary.


## CSV-format

To simplify the generation of the `accountmap.xml` file, we provide the script `$LLVIEW_HOME/da/utils/mapping_csv_to_xml.py` to be executed with the command:
```
python3 da/utils/mapping_csv_to_xml.py --csv accountmap.csv --loglevel DEBUG --xml accountmap.xml 
```

This script expects a CSV file (`accountmap.csv` in the line above) with the following arrangement (the order should be kept):

```
# username, project_mentor, project_pa, project_pi, project_user, support
username1, "project1,project2", "", "project1", "project1,project2,project3", true
username2, "project3", "", "", "", false
username3, "", "project1", "project2,project3", "project1,project2,project3", false
```

It will then generate a `accountmap.xml` file with the contents shown [above](#xml-format).
