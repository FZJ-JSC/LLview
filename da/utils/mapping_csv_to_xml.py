#!/usr/bin/env python3
# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Filipe Guimarães (Forschungszentrum Juelich GmbH)

import argparse
import logging
import sys
import csv
import time
import math

# from datetime import datetime
# import re
# import os
# import csv
# from copy import deepcopy
# from subprocess import check_output



# def jobinfo(options: dict, jobs_info) -> dict:
#   """
#   Specific function to add extra items to jobinfo
#   """
#   log = logging.getLogger('logger')

#   jobextra = {}

#   # Updating the jobs dictionary by adding or removing keys
#   for jobname,jobinfo in jobs_info.items():
#     # Adding status and detailedstatus to jobs
#     jobinfo['status'],jobinfo['detailedstatus'] = get_state(jobinfo['JobState'] if 'JobState' in jobinfo else "", jobinfo['Reason'] if 'Reason' in jobinfo else "")
#     jobinfo['MinCPUsNode'] = int(int(jobinfo['NumCPUs'])/int(jobinfo['NumNodes']))
#     if 'totaltasks' not in jobinfo:
#       jobinfo['totaltasks'] = int(int(jobinfo['NumCPUs'])/int(jobinfo['CPUs/Task']))
#     if 'NodeList' in jobinfo and jobinfo['NodeList']:
#       jobinfo['NodeList'] = add_CPUs_to_nodelist(jobinfo['NodeList'],jobinfo['MinCPUsNode'])
#     if 'SchedNodeList' in jobinfo and jobinfo['SchedNodeList']:
#       jobinfo['SchedNodeList'] = add_CPUs_to_nodelist(jobinfo['SchedNodeList'],jobinfo['MinCPUsNode'])
    
#     # jobinfo['totaltasks'] = jobinfo['NumCPUs'] 'totaltasks' $jobs{"$jobid"}{NumCPUs} if (!exists($jobs{"$jobid"}{totaltasks}))


#   # Gathering information about the job steps
#   # steps = SlurmInfo()
#   # steps.parse('scontrol show steps')
#   # # steps.to_LML('./steps_LML.xml',prefix='st',stype='steps')
#   # for stepname,step in steps.items():
#   #   match = re.match('((\w+)\.\w+)',stepname)
#   #   jobid = re.match('((\w+)\.\w+)',stepname).group(2)


#   return jobextra

# class SlurmInfo:
#   """
#   Class that stores and processes information from Slurm output  
#   """
#   def __init__(self):
#     self._dict = {}
#     self._raw = {}
#     self.log   = logging.getLogger('logger')

#   def __add__(self, other):
#     first = self
#     second = other
#     first._raw |= second._raw
#     first.add(second._dict)
#     return first

#   def __iter__(self):
#     return (t for t in self._dict.keys())
    
#   def __len__(self):
#     return len(self._dict)

#   def items(self):
#     return self._dict.items()

#   def __delitem__(self,key):
#     del self._dict[key]

#   def add(self, to_add: dict, add_to=None):
#     """
#     (Deep) Merge dictionary 'to_add' into internal 'self._dict'
#     """
#     # self._dict |= dict
#     if not add_to:
#       add_to = self._dict
#     for bk, bv in to_add.items():
#       av = add_to.get(bk)
#       if isinstance(av, dict) and isinstance(bv, dict):
#         self.add(bv,add_to=av)
#       else:
#         add_to[bk] = deepcopy(bv)
#     return

#   def empty(self):
#     """
#     Check if internal dict is empty: Boolean function that returns True if _dict is empty
#     """
#     return not bool(self._dict)

#   def parse(self, cmd, timestamp="", prefix="", stype=""):
#     """
#     This function parses the output of Slurm commands
#     and returns them in a dictionary
#     """
#     # If a timestamp file is given, the query should be made in a given period
#     # This is set by the flags '-S <start_time> -E <end_time>' and the file
#     # 'timestampfile' stores the last timestamp for which information was obtained
#     if timestamp and ('file' in timestamp):
#       end_ts = time.time() - timestamp['ts_delay'] if 'ts_delay' in timestamp else 0

#       if os.path.isfile(timestamp['file']):
#         try:
#           with open(timestamp['file'], 'r') as f:
#             last_ts = float(f.readline())
#         except ValueError:
#           self.log.error(f"Error reading timestamp from {timestamp['file']}! Check if file is correct or delete it.\n")
#           return
#         self.log.debug(f"Last timestamp from {timestamp['file']}: {last_ts}\n")
#       else:
#         last_ts = end_ts-1*24*60*60
#         self.log.debug(f"Timestamp file {timestamp['file']} does not exist. Getting information from the last day...\n")
#       last_date = datetime.fromtimestamp(last_ts).strftime('%m/%d/%y-%H:%M:%S')
#       end_date = datetime.fromtimestamp(end_ts).strftime('%m/%d/%y-%H:%M:%S')
#       self.log.debug(f"Getting information from {last_date} to {end_date}\n")
#       cmd += f" -S {last_date} -E {end_date}"

#       # Write timestamp of last query to file
#       with open(timestamp['file'], 'w') as f:
#         f.write(f'{end_ts}')

#     # Getting Slurm raw output
#     rawoutput = check_output(cmd, shell=True, text=True)
#     # 'scontrol' has an output that is different from
#     # 'sacct' and 'sacctmgr' (the latter are csv-like)
#     if("scontrol" in cmd):
#       # If result is empty, return
#       if (re.match("No (.*) in the system",rawoutput)):
#         self.log.warning(rawoutput.split("\n")[0]+"\n")
#         return
#       # Getting unit to be parsed from first keyword
#       unitname = re.match("(\w+)",rawoutput).group(1)
#       self.log.debug(f"Parsing units of {unitname}...\n")
#       units = re.findall(f"({unitname}[\s\S]+?)\n\n",rawoutput)
#       for unit in units:
#         self.parse_unit_block(unit, unitname, prefix, stype)
#     else:
#       units = list(csv.DictReader(rawoutput.splitlines(), delimiter='|'))
#       if len(units) == 0:
#         self.log.warning(f"No output units from command {cmd}\n")
#         return
#       # Getting unit to be parsed from first keyword
#       unitname = re.match("(\w+)",rawoutput).group(1)
#       self.log.debug(f"Parsing units of {unitname}...\n")
#       for unit in units:
#         current_unit = unit[unitname]
#         self._raw[current_unit] = {}
#         # Adding prefix and type of the unit, when given in the input
#         if stype:
#           self._raw[current_unit]["__prefix"] = prefix
#         if stype:
#           self._raw[current_unit]["__type"] = stype
#         for key,value in unit.items():
#           self.add_value(key,value,self._raw[current_unit])

#     self._dict |= self._raw
#     return

#   def add_value(self,key,value,dict):
#     """
#     Function to add (key,value) pair to dict. It is separate to be easier to adapt
#     (e.g., to not include empty keys)
#     """
#     dict[key] = value if value != "(null)" else ""
#     return

#   def parse_unit_block(self, unit, unitname, prefix, stype):
#     """
#     Parse each of the blocks returned by Slurm into the internal dictionary self._raw
#     """
#     # self.log.debug(f"Unit: \n{unit}\n")
#     lines = unit.split("\n")
#     # first line treated differently to get the 'unit' name and avoid unnecessary comparisons
#     for pair in lines[0].strip().split(' '):
#       key, value = pair.split('=',1)
#       if key == unitname:
#         current_unit = value
#         self._raw[current_unit] = {}
#         # Adding prefix and type of the unit, when given in the input
#         if stype:
#           self._raw[current_unit]["__prefix"] = prefix
#         if stype:
#           self._raw[current_unit]["__type"] = stype
#       # JobName must be treated separately, as it does not occupy the full line
#       # and it may contain '=' and ' '
#       elif key == "JobName":
#         value = re.search(".*JobName=(.*)$",lines[0].strip()).group(1)
#         self._raw[current_unit][key] = value
#         break
#       self.add_value(key,value,self._raw[current_unit])

#     # Other lines must be checked if there are more than one item per line
#     # When one item per line, it must be considered that it may include '=' in 'value'
#     for line in [_.strip() for _ in lines[1:]]:
#       # Skip empty lines
#       if not line: continue
#       self.log.debug(f"Parsing line: {line}\n")
#       # It is necessary to handle lines that can contain '=' and ' ' in 'value' first
#       if len(splitted := line.split('=',1)) == 2: # Checking if line is splittable on "=" sign
#         key,value = splitted
#       else:  # If not, split on ":"
#         key,value = line.split(":",1)
#       # Here must be all fields that can contain '=' and ' ', otherwise it may break the workflow below 
#       if key in ['Comment','Reason','Command','WorkDir','StdErr','StdIn','StdOut','TRES','OS']: 
#         self.add_value(key,value,self._raw[current_unit])
#         continue
#       # Now the pairs are separated by space
#       for pair in line.split(' '):
#         if len(splitted := pair.split('=',1)) == 2: # Checking if line is splittable on "=" sign
#           key,value = splitted
#         else:  # If not, split on ":"
#           key,value = pair.split(":",1)
#         if key in ['Dist']: #'JobName'
#           self._raw[current_unit][key] = line.split(f'{key}=',1)[1]
#           break
#         self.add_value(key,value,self._raw[current_unit])
#     return

#   def apply_pattern(self,exclude="",include=""):
#     """
#     Loops over all units in self._dict to:
#     - remove items that match 'exclude'
#     - keep only items that match 'include'
#     """
#     to_remove = []
#     for unitname,unit in self._dict.items():
#       if exclude and self.check_unit(unitname,unit,exclude,text="excluded") == True:
#         to_remove.append(unitname)
#       if include and self.check_unit(unitname,unit,include,text="included") == False:
#         to_remove.append(unitname)
#     for unitname in to_remove:
#       del self._dict[unitname]
#     return
  
#   def check_unit(self,unitname,unit,pattern,text="included/excluded"):
#     """
#     Check 'current_unit' name with rules for exclusion or inclusion. (exclusion is applied first)
#     Returns True if unit is to be skipped
#     """
#     if isinstance(pattern,str): # If rule is a simple string
#       if re.match(pattern, unitname):
#         self.log.debug(f"Unit {unitname} is {text} due to {pattern} rule\n")
#         return True
#     elif isinstance(pattern,list): # If list of rules
#       for pat in pattern: # loop over list - that can be strings or dictionaries
#         if isinstance(pat,str): # If item in list is a simple string
#           if re.match(pat, unitname):
#             self.log.debug(f"Unit {unitname} is {text} due to {pat} rule in list\n")
#             return True
#         elif isinstance(pat,dict): # If item in list is a dictionary
#           for key,value in pat.items():
#             if isinstance(value,str): # if dictionary value is a simple string
#               if (key in unit) and re.match(value, unit[key]):
#                 self.log.debug(f"Unit {unitname} is {text} due to {value} rule in {key} key of list\n")
#                 return True
#             elif isinstance(value,list): # if dictionary value is a list
#               for v in value:
#                 if (key in unit) and re.match(v, unit[key]): # At this point, v in list can only be a string
#                   self.log.debug(f"Unit {unitname} is {text} due to {v} rule in list of {key} key of list\n")
#                   return True
#     elif isinstance(pattern,dict): # If dictionary with rules
#       for key,value in pattern.items():
#         if isinstance(value,str): # if dictionary value is a simple string
#           if (key in unit) and re.match(value, unit[key]):
#             self.log.debug(f"Unit {unitname} is {text} due to {value} rule in {key} key\n")
#             return True
#         elif isinstance(value,list): # if dictionary value is a list
#           for v in value:
#             if (key in unit) and re.match(v, unit[key]): # At this point, v in list can only be a string
#               self.log.debug(f"Unit {unitname} is {text} due to {v} rule in list of {key} key\n")
#               return True            
#     return False

#   def map(self, mapping_dict):
#     """
#     Map the dictionary using (key,value) pair in mapping_dict
#     (Keys that are not present are removed)
#     """
#     new_dict = {}
#     skip_keys = set()
#     for unit,item in self._dict.items():
#       new_dict[unit] = {}
#       for key,map in mapping_dict.items():
#         # Checking if key to be modified is in object
#         if key not in item:
#           skip_keys.add(key)
#           continue
#         new_dict[unit][map] = item[key]
#       # Copying also internal keys that are used in the LML
#       if '__type' in item:
#         new_dict[unit]['__type'] = item['__type']
#       if '__id' in item:
#         new_dict[unit]['__id'] = item['__id']
#       if '__prefix' in item:
#         new_dict[unit]['__prefix'] = item['__prefix']
#     if skip_keys:
#       self.log.warning(f"Skipped mapping keys (at least on one node): {', '.join(skip_keys)}\n")
#     self._dict = new_dict
#     return

#   def modify(self, modify_dict):
#     """
#     Modify the dictionary using functions given in modify_dict
#     """
#     skipped_keys = set()
#     for item in self._dict.values():
#       for key,modify in modify_dict.items():
#         # Checking if key to be modified is in object
#         if key not in item:
#           skipped_keys.add(key)
#           continue
#         if isinstance(modify,str):
#           for funcname in [_.strip() for _ in modify.split(',')]:
#             try:
#               func = globals()[funcname]
#               item[key] = func(item[key])
#             except KeyError:
#               self.log.error(f"Function {funcname} is not defined. Skipping it and keeping value {item[key]}\n")
#         elif isinstance(modify,list):
#           for funcname in modify:
#             try:
#               func = globals()[funcname]
#               item[key] = func(item[key])
#             except KeyError:
#               self.log.error(f"Function {funcname} is not defined. Skipping it and keeping value {item[key]}\n")
#     if skipped_keys:
#       self.log.warning(f"Skipped modifying keys (at least on one node): {', '.join(skipped_keys)}\n")
#     return

#   def to_LML(self, filename, prefix="", stype=""):
#     """
#     Create LML output file 'filename' using
#     information of self._dict
#     """
#     self.log.info(f"Writing LML data to {filename}... ")
#     # Opening LML file
#     with open(filename,"w") as file:
#       # Writing initial XML preamble
#       file.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" )
#       file.write("<lml:lgui xmlns:lml=\"http://eclipse.org/ptp/lml\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n" )
#       file.write("    xsi:schemaLocation=\"http://eclipse.org/ptp/lml http://eclipse.org/ptp/schemas/v1.1/lgui.xsd\"\n" )
#       file.write("    version=\"1.1\">\n" )

#       # Creating first list of objects
#       file.write("<objects>\n" )
#       digits = int(math.log10(len(self._dict)))+1 if len(self._dict)>0 else 1
#       i = 0
#       for key,item in self._dict.items():
#         if "__id" not in item:
#           item["__id"] = f'{prefix if prefix else item["__prefix"]}{i:0{digits}d}'
#           i += 1
#         file.write(f'<object id=\"{item["__id"]}\" name=\"{key}\" type=\"{stype if stype else item["__type"]}\"/>\n')
#       file.write("</objects>\n")

#       # Writing detailed information for each object
#       file.write("<information>\n")
#       # Counter of the number of items that define each object
#       i = 0
#       # Looping over the items
#       for item in self._dict.values():
#         # The objects are unique for the combination {jobid,path}
#         file.write(f'<info oid=\"{item["__id"]}\" type=\"short\">\n')
#         # Looping over the quantities obtained in this item
#         for key,value in item.items():
#           # The __nelems_{type} is used to indicate to DBupdate the number of elements - important when the file is empty
#           if key.startswith('__nelems'): 
#             file.write(" <data key={:24s} value=\"{}\"/>\n".format('\"'+str(key)+'\"',value))
#             continue
#           if key.startswith('__'): continue
#           if (value):
#           # if (value) and (value != "0"):
#             # Replacing double quotes with single quotes to avoid problems importing the values
#             file.write(" <data key={:24s} value=\"{}\"/>\n".format('\"'+str(key)+'\"',value.replace('"', "'") if isinstance(value, str) else value))
#         # if ts:
#         #   file.write(" <data key={:24s} value=\"{}\"/>\n".format('\"ts\"',ts))

#         file.write(f"</info>\n")
#         i += 1

#       file.write("</information>\n" )
#       file.write("</lml:lgui>\n" )

#     log_continue(self.log,"Finished!")

#     return


# def log_continue(log,message):
#   """
#   Change formatter to write a continuation 'message' on the logger 'log' and then change the format back
#   """
#   for handler in log.handlers:
#     handler.setFormatter(CustomFormatter("%(message)s (%(lineno)-3d)[%(asctime)s]\n",datefmt=log_config['datefmt']))

#   log.info(message)

#   for handler in log.handlers:
#     handler.setFormatter(CustomFormatter(log_config['format'],datefmt=log_config['datefmt']))
#   return


# def get_system_name() -> str:
#   """
#   Get system name from environment variable or from file
#   If not present on both, return unknown
#   """
#   log = logging.getLogger('logger')

#   # Trying to get from environment variable first
#   systemname = os.environ.get('SYSTEMNAME')
#   # If not present, try to get from file
#   if not systemname:
#     try:
#       with open("/etc/FZJ/systemname", 'r') as file:
#         systemname = file.read()
#     except FileNotFoundError:
#       log.error("Could not get system name from environment $SYSTEMNAME nor file /etc/FZJ/systemname. ")
#       systemname = 'unknown'
#   systemname = systemname.strip()
#   log.info(f'Using system name: {systemname}\n')
#   return systemname


# def parse_config_yaml(filename):
#   """
#   YML configuration parser
#   """
#   import yaml
#   with open(filename, 'r') as configyml:
#     configyml = yaml.safe_load(configyml)
#   return configyml

def dict_to_lml(csvdict: dict, xmlfile: str):
  """
  This function receives the dictionary created by 'csv_to_dict' and outputs 
  an XML file 'xmlfile' containing the information.
  """
  log = logging.getLogger('logger')

  log.info(f"Writing XML data to {xmlfile}...")

  # Opening LML file
  with open(xmlfile,"w") as file:
    # Writing initial XML preamble
    file.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" )
    file.write("<lml:lgui>\n" )

    # Creating first list of objects
    file.write(f"{2*' '}<objects>\n" )
    # Looping over the roles
    for role,entries in csvdict.items():
      digits = int(math.log10(len(entries)))
      i = 0
      # Looping over the entries in each role
      for entry in entries:
        i += 1
        file.write(f'{4*" "}<object id=\"{role[0].upper() if role[0] != "p" else "Q"}{i:0{digits}d}\" name=\"{entry["id"]+(("_"+entry["kind"]) if "kind" in entry else "")}\" type=\"{role}map\"/>\n')
    file.write(f"{2*' '}</objects>\n")

    # Writing detailed information for each object
    file.write(f"{2*' '}<information>\n")
    # Looping over the roles
    for role,entries in csvdict.items():
      digits = int(math.log10(len(entries)))
      i = 0
      # Looping over the entries in each role
      for entry in entries:
        i += 1
        # The objects are unique for each username/role
        file.write(f'{4*" "}<info oid=\"{role[0].upper() if role[0] != "P" else "Q"}{i:0{digits}d}\" type=\"short\">\n')
        # Looping over the keys and values and entries
        for key,value in entry.items():
          # Replacing double quotes with single quotes to avoid problems importing the values
          file.write(f"{6*' '}<data key=\"{key}\" value=\"{value}\"/>\n")
          # file.write(" <data key={:24s} value=\"{}\"/>\n".format('\"'+str(key)+'\"',value.replace('"', "'") if isinstance(value, str) else value))
        # if ts:
        #   file.write(" <data key={:24s} value=\"{}\"/>\n".format('\"ts\"',ts))

      file.write(f"{4*' '}</info>\n")

    file.write(f"{2*' '}</information>\n" )
    file.write("</lml:lgui>\n" )

  return

def csv_to_dict(csvfile: str) -> dict:
  """
  This function opens and reads a CSV file containing, in this order:

    username, mentored projects, administered projects (PA), leadered projects (PI), joined projects (User), Support (true or false)
  
  Lines starting with '#' and empty lines are skipped. It returns the in a dictionary form:

  'mentor': [list of dicts with mentors (each containing the mentored projects)],
  'pa': [list of dicts with PAs (each containing the administered projects)],
  'pi': [list of dicts with PIs (each containing the leadered projects)],
  'user': [list of dicts with Users (each containing the joined projects)],
  'support': [list of dicts with supporters]

  """
  log = logging.getLogger('logger')

  log.info(f"Reading CSV data from {csvfile}...")

  ts = int(time.time())
  csvdict = {}

  with open(csvfile) as file:
    data = csv.reader(filter(lambda row: (row[0]!='#' and row.strip()), file), quotechar='"', delimiter=',', quoting=csv.QUOTE_ALL,skipinitialspace=True)

    for row in data:
      username = row[0]
      for role,indices in {'mentor':[1],'pipa': [2,3],'user':[4]}.items():
        for index in indices:
          projects = row[index].strip()
          if not projects: continue
          csvdict.setdefault(role, []).append( dict(
                                                    id=username,
                                                    projects=projects,
                                                    ts=ts,
                                                    wsaccount=username
                                                    )
                                              )
          if index == 2:
            csvdict[role][-1]['kind'] = 'A'
          elif index == 3:
            csvdict[role][-1]['kind'] = 'L'
      if row[5].strip()=="true":
        csvdict.setdefault('support', []).append( dict(
                                                        id=username,
                                                        ts=ts,
                                                        wsaccount=username
                                                      )
                                                )

  log.debug(f"Dictionary from the CSV:\n{csvdict}")

  return csvdict

class CustomFormatter(logging.Formatter):
  """
  Formatter to add colors to log output
  (adapted from https://stackoverflow.com/a/56944256/3142385)
  """
  def __init__(self,fmt,datefmt=""):
    super().__init__()
    self.fmt=fmt
    self.datefmt=datefmt
    # Colors
    self.grey = "\x1b[38;20m"
    self.yellow = "\x1b[93;20m"
    self.blue = "\x1b[94;20m"
    self.magenta = "\x1b[95;20m"
    self.cyan = "\x1b[96;20m"
    self.red = "\x1b[91;20m"
    self.bold_red = "\x1b[91;1m"
    self.reset = "\x1b[0m"
    # self.format = "%(asctime)s %(funcName)-18s(%(lineno)-3d): [%(levelname)-8s] %(message)s"

    self.FORMATS = {
                    logging.DEBUG: self.cyan + self.fmt + self.reset,
                    logging.INFO: self.grey + self.fmt + self.reset,
                    logging.WARNING: self.yellow + self.fmt + self.reset,
                    logging.ERROR: self.red + self.fmt + self.reset,
                    logging.CRITICAL: self.bold_red + self.fmt + self.reset
                  }
    
  def format(self, record):
    log_fmt = self.FORMATS.get(record.levelno)
    formatter = logging.Formatter(fmt=log_fmt,datefmt=self.datefmt)
    return formatter.format(record)
    
# Adapted from: https://stackoverflow.com/a/53257669/3142385
class _ExcludeErrorsFilter(logging.Filter):
    def filter(self, record):
        """Only lets through log messages with log level below ERROR ."""
        return record.levelno < logging.ERROR

log_config = {
              'format': "%(asctime)s %(funcName)-18s(%(lineno)-3d): [%(levelname)-8s] %(message)s",
              'datefmt': "%Y-%m-%d %H:%M:%S",
              # 'file': 'mapping.log',
              # 'filemode': "w",
              'level': "INFO" # Default value; Options: 'DEBUG', 'INFO', 'WARNING', 'ERROR' from more to less verbose logging
              }
def log_init(level):
  """
  Initialize logger
  """

  # Getting logger
  log = logging.getLogger('logger')
  log.setLevel(level if level else log_config['level'])

  # Setup handler (stdout, stderr and file when configured)
  oh = logging.StreamHandler(sys.stdout)
  oh.setLevel(level if level else log_config['level'])
  oh.setFormatter(CustomFormatter(log_config['format'],datefmt=log_config['datefmt']))
  oh.addFilter(_ExcludeErrorsFilter())
  # oh.terminator = ""
  log.addHandler(oh)  # add the handler to the logger so records from this process are handled

  eh = logging.StreamHandler(sys.stderr)
  eh.setLevel('ERROR')
  eh.setFormatter(CustomFormatter(log_config['format'],datefmt=log_config['datefmt']))
  # eh.terminator = ""
  log.addHandler(eh)  # add the handler to the logger so records from this process are handled

  if 'file' in log_config:
    fh = logging.FileHandler(log_config['file'], mode=log_config['filemode'])
    fh.setLevel(level if level else log_config['level'])
    fh.setFormatter(CustomFormatter(log_config['format'],datefmt=log_config['datefmt']))
    fh.terminator = ""
    log.addHandler(fh)  # add the handler to the logger so records from this process are handled

  return


################################################################################
# MAIN PROGRAM:
################################################################################
def main():
  """
  Main program
  """
  
  # Parse arguments
  parser = argparse.ArgumentParser(description="Slurm Adapter for LLview")
  # parser.add_argument("--LMLjobfile",  default="./jumonc_LML.xml", help="Output LML file for information of jobs")
  parser.add_argument("--csv",     required=True, help="Input CSV to be converted")
  parser.add_argument("--xml",     required=True, help="Output XML")
  parser.add_argument("--loglevel",default=False, help="Select log level: 'DEBUG', 'INFO', 'WARNING', 'ERROR' (more to less verbose)")
  # parser.add_argument("--PAT_NODES", default=False,      help="Pattern of node names to gather information from")

  args = parser.parse_args()

  # Configuring the logger (level and format)
  log_init(args.loglevel)
  log = logging.getLogger('logger')

  # Saving information from csv into a dict
  csvdict = csv_to_dict(args.csv)

  # Writing XML file
  dict_to_lml(csvdict,args.xml)

  log.info("Done")

  return

if __name__ == "__main__":
  main()
