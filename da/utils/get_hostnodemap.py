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
import re
import math

def to_lml(nodelist: dict, xmlfile: str):
  """
  This function receives the list created by 'read_map' and outputs 
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

    digits = int(math.log10(len(nodelist)))+1
    i = 0
    # Looping over the entries in each role
    for node in nodelist:
      i += 1
      file.write(f'{4*" "}<object id=\"ic{i:0{digits}d}\" name=\"{node["id"]}\" type=\"icmap\"/>\n')
    file.write(f"{2*' '}</objects>\n")

    # Writing detailed information for each object
    file.write(f"{2*' '}<information>\n")
    # Looping over the roles
    i = 0
    # Looping over the entries in each role
    for node in nodelist:
      i += 1
      # The objects are unique for each username/role
      file.write(f'{4*" "}<info oid=\"ic{i:0{digits}d}\" type=\"short\">\n')
      # Looping over the keys and values and entries
      for key,value in node.items():
        # Replacing double quotes with single quotes to avoid problems importing the values
        file.write(f"{6*' '}<data key=\"{key}\" value=\"{value}\"/>\n")
        # file.write(" <data key={:24s} value=\"{}\"/>\n".format('\"'+str(key)+'\"',value.replace('"', "'") if isinstance(value, str) else value))
      # if ts:
      #   file.write(" <data key={:24s} value=\"{}\"/>\n".format('\"ts\"',ts))

      file.write(f"{4*' '}</info>\n")

    file.write(f"{2*' '}</information>\n" )
    file.write("</lml:lgui>\n" )

  return

def read_map(filemap: str) -> dict:
  """
  This function opens a mapping file in the form:

    nodelist_range[:str]  cell[:int]

    For example:

    nd[0001-0005,0015-0020]  1
    nd[0006-0015]  2
    ...

  Lines starting with '#' and empty lines are skipped. It returns a list of dicts in the form:

  [{id="nd0001",nr=1,ts="1683125366"},{id="nd0002",nr=1,ts="1683125366"},... ]

  """
  log = logging.getLogger('logger')

  log.info(f"Reading map from {filemap}...")

  ts = int(time.time())
  nodelist = []

  with open(filemap) as file:
    data = csv.reader(filter(lambda row: (row[0]!='#' and row.strip()), file), quotechar='"', delimiter=' ', quoting=csv.QUOTE_ALL,skipinitialspace=True)

    for row in data:
      for node in expand_NodeList(row[0]):
        nodelist.append(dict(
                              id=node,
                              nr=row[1],
                              ts=ts
                            ))

  log.debug(f"List of node map:\n{nodelist}")
  return nodelist


def expand_NodeList(nodelist: str) -> list:
  """
  Split node list by commas only between groups of nodes, not within groups
  Returns all complete node names separated by a single space
  Regex notes:
    [^\[]+ - matches anything (at lest one character) but the '[' literal
    (?:\[[\d,-]*\])? - matches zero or one (optional) node groupings like '[1,3,5-8,10]'
    General Documentation https://docs.python.org/3/library/re.html#regular-expression-syntax
  """
  expandedlist = []
  for nodelist in re.findall('([^\[]+(?:\[[\d,-]*\])?),?',nodelist):
    match = re.findall( "(.+?)\[(.*?)\]|(.+)", nodelist)[0]
    if match[2] == nodelist:
      # single node
      expandedlist.append(f"{nodelist}")
      continue
    # multiple nodes in node list as in "node[a,b,m-n,x-y]"
    for node in match[1].split(','):
      # splitting eventual consecutive nodes with '-'
      list = node.split('-',1)
      if len(list)==1:
        # single node
        expandedlist.append(f"{match[0]}{list[0]}")
      else:
        # multi-node separated by '-'
        for i in range(int(list[0]),int(list[1])+1):
          expandedlist.append(f"{match[0]}{i:0{len(list[0])}}")
  return expandedlist


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
  parser = argparse.ArgumentParser(description="LLview's interconnect XML map creation")
  parser.add_argument("--map",     required=True, help="Input map")
  parser.add_argument("--xml",     required=True, help="Output XML")
  parser.add_argument("--loglevel",default=False, help="Select log level: 'DEBUG', 'INFO', 'WARNING', 'ERROR' (more to less verbose)")

  args = parser.parse_args()

  # Configuring the logger (level and format)
  log_init(args.loglevel)
  log = logging.getLogger('logger')

  # Saving information from csv into a dict
  nodelist = read_map(args.map)

  # Writing XML file
  to_lml(nodelist,args.xml)

  log.info("Done")

  return

if __name__ == "__main__":
  main()
