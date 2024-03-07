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
        file.write(f'{4*" "}<info oid=\"{role[0].upper() if role[0] != "p" else "Q"}{i:0{digits}d}\" type=\"short\">\n')
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
  parser = argparse.ArgumentParser(description="LLview's account map conversion tool (CSV to XML)")
  parser.add_argument("--csv",     required=True, help="Input CSV to be converted")
  parser.add_argument("--xml",     required=True, help="Output XML")
  parser.add_argument("--loglevel",default=False, help="Select log level: 'DEBUG', 'INFO', 'WARNING', 'ERROR' (more to less verbose)")

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
