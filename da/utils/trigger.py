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
import time
import math

def to_lml(items: dict, xmlfile: str):
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

    digits = int(math.log10(len(items)))+1
    i = 0
    # Looping over the entries in each role
    for item in items:
      i += 1
      file.write(f'{4*" "}<object id=\"ts{i:0{digits}d}\" name=\"{item["__id"]}\" type=\"{item["__type"]}\"/>\n')
    file.write(f"{2*' '}</objects>\n")

    # Writing detailed information for each object
    file.write(f"{2*' '}<information>\n")
    # Looping over the roles
    i = 0
    # Looping over the entries in each role
    for item in items:
      i += 1
      # The objects are unique for each username/role
      file.write(f'{4*" "}<info oid=\"ts{i:0{digits}d}\" type=\"short\">\n')
      # Looping over the keys and values and entries
      for key,value in item.items():
        if key.startswith('__'): continue
        # Replacing double quotes with single quotes to avoid problems importing the values
        file.write(f"{6*' '}<data key=\"{key}\" value=\"{value}\"/>\n")
        # file.write(" <data key={:24s} value=\"{}\"/>\n".format('\"'+str(key)+'\"',value.replace('"', "'") if isinstance(value, str) else value))
      # if ts:
      #   file.write(" <data key={:24s} value=\"{}\"/>\n".format('\"ts\"',ts))

      file.write(f"{4*' '}</info>\n")

    file.write(f"{2*' '}</information>\n" )
    file.write("</lml:lgui>\n" )

  return


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
  parser = argparse.ArgumentParser(description="LLview's trigger XML creation")
  parser.add_argument("--xml",     required=True, help="Output XML")
  parser.add_argument("--loglevel",default=False, help="Select log level: 'DEBUG', 'INFO', 'WARNING', 'ERROR' (more to less verbose)")

  args = parser.parse_args()

  # Configuring the logger (level and format)
  log_init(args.loglevel)
  log = logging.getLogger('logger')

  # Writing XML file
  log.info("Creating trigger XML")
  items = [
            {
              "__id": "ts",
              "__type": "trigger",
              "ts": int(time.time())
            }
          ]
  to_lml(items,args.xml)

  log.info("Done")

  return

if __name__ == "__main__":
  main()
