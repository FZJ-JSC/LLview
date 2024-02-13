# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Filipe Guimarães (Forschungszentrum Juelich GmbH) 

import os                                                  # OS library (files and folders operations)
import sys                                                 # system variables for stdout and stderr
import json                                                # JSON library for the outputs
import glob                                                # Expansion of wildcards on filenames
from matplotlib.backends.backend_pdf import PdfPages       # Multi-Page PDF library
from matplotlib import rcParams                            # Configuration of figures, axis and plots
from matplotlib import colormaps                           # Get cmap from colors
from matplotlib.colors import LinearSegmentedColormap      # Create Colormap
from cycler import cycler                                  # Cycler for colors
from math import ceil                                      # Ceiling for float to integer conversion
import numpy as np                                         # Numerical library
import pandas as pd                                        # Database Library
import re                                                  # Regular Expression library
import multiprocessing as mp                               # Multi-processing library for parallel jobs
import logging
from logging.handlers import QueueHandler, QueueListener, TimedRotatingFileHandler
import traceback
import time
import argparse
import itertools
import shutil
import yaml
import datetime 
from pytz import timezone


# Program subfiles
import FirstPage
import CreateReports
import LastPages
import Nodelist
import msg
import GenerateHTML
from PlotlyFigs import CreateUnifiedPlotlyFig

def check_shutdown():
  """
  Check if the shutdown file exists
  """
  if(any([os.path.exists(file) for file in shutdown_file])):
    log.warning("Shutdown file found! Stopping...")
    return True
  else:
    return False

def check_shutdown_callback(self):
  """
  Callback used after every job to check if shutdown file exists
  to terminate the jobs
  """  
  if check_shutdown():
    if email: msg.send_email(semail,remail,"Shutdown file found, stopping generation of PDF-job reports")
    log.warning("Shutdown file found, stopping jobs")
    pool.terminate()
  return

def error_handler(e):
  """
  Error callback to catch any raised exception raised by some
  of the child processes, and send email
  """  
  if email: msg.send_email(semail,remail,f"Error in PDF-Job report:\n {' '.join(traceback.format_exception(type(e), e, e.__traceback__))}")
  log.error(f"Error:\n {' '.join(traceback.format_exception(type(e), e, e.__traceback__))}")
  global nerrors
  nerrors += 1
  return

def add_color(x):
  if (x == 'COMPLETED'):
    color = (0.0,0.5,0.0,0.5) # green
    edgecolor = (0.0,0.5,0.0)
  elif ('FAIL' in x):
    color = (1.0,0.0,0.0,0.5) # red
    edgecolor = (1.0,0.0,0.0)
  elif (x == 'RUNNING'):
    color = (0.0,0.0,1.0,0.5) # blue
    edgecolor = (0.0,0.0,1.0)
  else:
    color = (0.85,0.65,0.13,0.5) #'goldenrod'
    edgecolor = (0.85,0.65,0.13)
  colorhtml = f"rgba{(color[0]*255,color[1]*255,color[2]*255,color[3])}"
  edgecolorhtml = f"rgb{(edgecolor[0]*255,edgecolor[1]*255,edgecolor[2]*255)}"
  return pd.Series([color,edgecolor,colorhtml,edgecolorhtml])


def ProcessReport(njob,total_jobs,job,config):
  """
  Wrapper to catch eventual errors in _ProcessReport
  """
  log = logging.getLogger('logger')
  
  try:
    _ProcessReport(njob,total_jobs,job,config)
  except Exception as e:
    log.error(f"Error in job {job}:\n {' '.join(traceback.format_exception(type(e), e, e.__traceback__))}")
    raise


def _ProcessReport(njob,total_jobs,job,config):
  """
  PDF generation for a given job report
  """
  # Starting timer for current job
  start_job = time.time()
  # Getting logger for this process
  log = logging.getLogger('logger')
  log.debug(f"{njob}/{total_jobs}: {job}")

  # Getting folder and filename for this job
  folder,file = os.path.split(job)

  # Reading information for this job
  with open(job) as json_file:
    data = json.load(json_file)

  # Getting timezonegap
  config['appearance']['timezonegap'] = timezone(config['appearance']['timezone']).localize(datetime.datetime.strptime(data["job"]["starttime"],'%Y-%m-%d %H:%M:%S')).utcoffset().seconds
  
  # Removing sensitive data in demo mode
  if config['demo']:
    # folder = "."
    data["job"]["owner"] = "username"
    data["job"]["account"] = "project"
    data["job"]["name"] = "job name"
    data['files']['pdffile'] = f"jobreport_{data['job']['system']}_{njob}.pdf"

  # Flag for finished jobs
  finished =  bool(data['job']['finished'])

  # Getting number of CPUs and GPUs and setting flag for GPU jobs
  num_cpus = int(data['job']['numnodes'])
  try:
    num_gpus = int(data['job']['numgpus'])
    if num_gpus == 0:
      gpus = False
    else:
      if(data['gpu']['gpulist']=="0"):
        log.warning("No GPU information yet - report skipped!")
        return    # skip job without the GPU list
      data['gpu']['gpu_usage_avg'] = float(data['gpu']['gpu_usage_avg'])
      gpus = True
  except (ValueError,KeyError):
    data['job']['numgpus'] = 0
    num_gpus = 0
    gpus = False

  # Configuring plots (from plots.yml)
  sections = [_ for _ in config['plots'] if _ not in ['x','y']]

  # If GPU info is present on the json but there's no GPU section to plot, turn GPU off
  if 'GPU' not in sections: gpus = False

  # Looping through the sections (CPU, GPU, File systems, etc.)
  for section in sections:
    # Skipping GPU section if job has no GPU
    if not gpus and section == "GPU": continue
    # Looping through the "inner sections" (i.e. graphs), skipping the ones with 'json' (which includes information for the json file)
    for graph in [_ for _ in config['plots'][section] if not _.startswith('_') and _ not in ['x','y']]:
      # If a limit is given, check if it is a memory limit (defined in system_info.yml)
      if 'lim' in config['plots'][section][graph]:
        if config['plots'][section][graph]['lim']:
          config['plots'][section][graph]['lim'] = [ config['system'][data['job']['system'].upper()][ data['job']['queue'] ][_] if isinstance(_, str) else _ for _ in config['plots'][section][graph]['lim'] ]
      else:
        config['plots'][section][graph]['lim'] = False

  # Check if line plots were chosen
  data['colorplot'] = True
  if 'comment' in data['job'] and 'llview_plot_lines' in data['job']['comment']:
    # Choose line_plots instead of colorplots (from slurm comment?)
    if (gpus and num_gpus<=16) or (not gpus and num_cpus<=16):
      data['colorplot'] = False

  # Tick properties
  rcParams['xtick.top'] = 'on'
  rcParams['xtick.bottom'] = 'on'
  rcParams['ytick.left'] = 'on'
  rcParams['ytick.right'] = 'on'
  rcParams['xtick.direction'] = 'in'
  rcParams['ytick.direction'] = 'in'
  rcParams['xtick.labelsize'] = config['appearance']['tinyfont']
  rcParams['ytick.labelsize'] = config['appearance']['tinyfont']
  # Font properties
  rcParams["font.sans-serif"] = ["Liberation Sans", "Arial"]
  rcParams["font.monospace"] = ['Liberation Mono', 'Courier New']
  rcParams["font.family"] = "sans-serif"
  rcParams['font.weight'] = 'normal'
  rcParams['font.size'] = config['appearance']['normalfont']
  # Axes properties
  rcParams['axes.linewidth'] = 0.5
  rcParams['lines.linewidth'] = 1.0
  rcParams['axes.facecolor'] = 'whitesmoke'
  rcParams['axes.prop_cycle'] = cycler('color', config['appearance']['colors_cmap'])


  tocentries = {'Overview':1}
  df = {}
  df_custom = {}
  to_plot = {}
  page_num = 2
  for section in sections:
    ######################################### Reading data #########################################
    # If points are not there, add 0
    if(config['plots'][section]['_datapoints_header'] not in data['num_datapoints']): data['num_datapoints'][config['plots'][section]['_datapoints_header']] = 0
    if (int(data['num_datapoints'][config['plots'][section]['_datapoints_header']])>1) and (data['files'][config['plots'][section]['_file_header']] not in ["",0,"-"]):
      # Getting which graphs to plot
      graphs = [_ for _ in config['plots'][section] if not _.startswith('_') and _ not in ['x','y']]

      # Reading file with information for all nodes and all times
      with open(f"{folder}/{data['files'][config['plots'][section]['_file_header']]}",'r') as file:
        header = file.readline().rstrip().strip("#").split()

        # Columns to store (from config)
        # Getting x headers from graphs, if present
        x_headers = {config['plots'][section][_]['x']['header']: config['plots'][section][_]['x']['type'] for _ in graphs if 'x' in config['plots'][section][_]}
        # if there are graphs with undefined x header, add default x header (from main or section)
        if not graphs or [_ for _ in graphs if 'x' not in config['plots'][section][_]]:
          x_headers |= {config['plots'][section]['x']['header']: config['plots'][section]['x']['type']} if ('x' in config['plots'][section] and 'header' in config['plots'][section]['x']) else {config['plots']['x']['header']: config['plots']['x']['type']}
        # Getting y headers from graphs, if present
        y_headers = {config['plots'][section][_]['y']['header']: config['plots'][section][_]['y']['type'] for _ in graphs if 'y' in config['plots'][section][_]}
        # if there are graphs with undefined y header, add default y header (from main or section)
        if not graphs or [_ for _ in graphs if 'y' not in config['plots'][section][_]]:
          y_headers |= {config['plots'][section]['y']['header']: config['plots'][section]['y']['type']} if ('y' in config['plots'][section] and 'header' in config['plots'][section]['y']) else {config['plots']['y']['header']: config['plots']['y']['type']}
        cols = { 
                  **x_headers,
                  **y_headers,
                  **{config['plots'][section][_]['header']:config['plots'][section][_]['type'] for _ in graphs},
                }

        # If list of graphs is empty, it means that the section is defined, but not the graphs
        # This is then a User-defined/Custom section
        # Then we add the given file "as is" to df_custom
        if not graphs:
          df_temp = pd.read_csv(file, delim_whitespace=True, comment='#', names=header, index_col=False)
        else:
          # Else, get the headers given on the graph list
          icols = [header.index(_) for _ in cols.keys()]
          # Reading database
          df_temp = pd.read_csv(file, delim_whitespace=True, comment='#', names=header, index_col=False, usecols=icols,dtype=cols)[cols.keys()]

        # Getting header title for timestamp and nodelist
        y_x_keys = [key for key in {**y_headers, **x_headers}.keys()]

        # Dropping duplicated lines
        df_temp.drop_duplicates(subset=y_x_keys, keep='first', inplace=True) 

        # Dropping rows above ts range
        if config['appearance']['maxsec']:
          df_temp.drop(df_temp[df_temp[config['plots']['x']['header']] > df_temp[config['plots']['x']['header']].min()+config['appearance']['maxsec']].index, inplace=True) 

        # Completing the dataframe by ts and node
        # Build the full MultiIndex, set the partial MultiIndex, and reindex.
        full_idx = pd.MultiIndex.from_product([df_temp[col].unique() for col in y_x_keys], names=y_x_keys)
        df_temp = df_temp.set_index(y_x_keys).reindex(full_idx)
        df_temp = df_temp.groupby(level=y_x_keys[0]).fillna(value=(np.nan if '_fill_with' not in config['plots'][section] else config['plots'][section]['_fill_with'])).reset_index()
        # df_temp = df_temp.set_index(y_x_keys)\
        #                          .unstack(level=y_x_keys[1])\
        #                          .stack(level=y_x_keys[1], dropna=False)
        # df_temp = df_temp.groupby(level=y_x_keys[1]).fillna(0.0).reset_index()

        # Creating datetime entry (for plotting)
        # df_temp['datetime']= pd.to_datetime(df_temp['ts']+config.timezonegap,unit='s')

        # Repeating last line to be able to plot the real last one with pcolormesh
        for key,value in y_headers.items():
          if value == "str":
            new_line = df_temp.loc[df_temp[key]==df_temp.tail(1)[key].values[0]].copy()
            new_line.loc[:,key] = 'zzz'
            df_temp = pd.concat([df_temp,new_line],ignore_index=True)
        # Sorting DF
        df_temp.sort_values(y_x_keys, ascending=[True,True], inplace=True)

        # Setting df_temp to the corresponsing df (user-defined or configuration-defined)
        if not graphs:
          df_custom[section] = df_temp
          continue
        else:
          df[section] = df_temp
    ################################# Setting up TOC and graphs ####################################
      max_graph_per_page = config['plots'][section]['_max_graph_per_page'] if '_max_graph_per_page' in config['plots'][section] else config['appearance']['max_graph_per_page']
      for pg in range(int((len(graphs)-1)/max_graph_per_page)+1):
        i0 = max_graph_per_page*pg
        i1 = i0+max_graph_per_page
        to_plot[page_num] = {}
        to_plot[page_num]['type']    = section
        to_plot[page_num]['data']    = df[section]
        to_plot[page_num]['graphs']  = graphs[i0:i1]
        to_plot[page_num]['headers'] = []
        to_plot[page_num]['unit']    = []
        to_plot[page_num]['cmap']    = []
        to_plot[page_num]['lim']     = []
        to_plot[page_num]['log']     = []
        to_plot[page_num]['x']       = []
        to_plot[page_num]['xlabel']  = []
        to_plot[page_num]['y']       = []
        to_plot[page_num]['ylabel']  = []
        to_plot[page_num]['note']    = []
        to_plot[page_num]['colorplot'] = []
        to_plot[page_num]['unified'] = []
        # Looping over graphs that will be plotted in this given page
        for _ in graphs[i0:i1]:
          # Removing 0.0 in log plots
          if config['plots'][section][_]['log']:
            df[section][config['plots'][section][_]['header']] = df[section][config['plots'][section][_]['header']].replace(0, np.nan)

          # If 'skip_when_all' is present, check if dataframe values are all equal given value
          if 'skip_when_all' in config['plots'][section][_]:
            # If 'skip_when_all'=nan and the database is empty, remove it
            # Testing if value is str first
            if isinstance(config['plots'][section][_]['skip_when_all'], str):
              if config['plots'][section][_]['skip_when_all'].lower() == 'nan' and df[section][config['plots'][section][_]['header']].isnull().all():
                del df[section][config['plots'][section][_]['header']]
                to_plot[page_num]['graphs'].remove(_)
                continue
            else:
              # If all elements in database equals value defined in plots.yml, remove it
              if(df[section][config['plots'][section][_]['header']].eq(config['plots'][section][_]['skip_when_all']).all()):
                del df[section][config['plots'][section][_]['header']]
                to_plot[page_num]['graphs'].remove(_)
                continue

          to_plot[page_num]['headers'].append(config['plots'][section][_]['header'])
          # to_plot[page_num]['factor'].append(config['plots'][section][_]['factor'])
          to_plot[page_num]['unit'].append(config['plots'][section][_]['unit'])
          to_plot[page_num]['cmap'].append(config['plots'][section][_]['cmap'])
          to_plot[page_num]['lim'].append(config['plots'][section][_]['lim'])
          to_plot[page_num]['log'].append(config['plots'][section][_]['log'])
          # Defining the header and label to be used for x, depending if they are defined in graph, section or main only (in this priority order)
          if 'x' in config['plots'][section][_]:
            to_plot[page_num]['x'].append(config['plots'][section][_]['x']['header'])
            to_plot[page_num]['xlabel'].append(config['plots'][section][_]['x']['name'] if 'name' in config['plots'][section][_]['x'] else "")
          else:
            to_plot[page_num]['x'].append(config['plots'][section]['x']['header'] if ('x' in config['plots'][section] and 'header' in config['plots'][section]['x']) else config['plots']['x']['header'])
            to_plot[page_num]['xlabel'].append(config['plots'][section]['x']['name'] if ('x' in config['plots'][section] and 'name' in config['plots'][section]['x']) else config['plots']['x']['name'] if 'name' in config['plots']['x'] else "")
          # Defining the header and label to be used for y, depending if they are defined in graph, section or main only (in this priority order)
          if 'y' in config['plots'][section][_]:
            to_plot[page_num]['y'].append(config['plots'][section][_]['y']['header'])
            to_plot[page_num]['ylabel'].append(config['plots'][section][_]['y']['name'] if 'name' in config['plots'][section][_]['y'] else "")
          else:
            to_plot[page_num]['y'].append(config['plots']['y']['header'])
            to_plot[page_num]['ylabel'].append(config['plots'][section]['y']['name'] if ('y' in config['plots'][section] and 'name' in config['plots'][section]['y']) else config['plots']['y']['name'] if 'name' in config['plots']['y'] else "")
          to_plot[page_num]['colorplot'].append(True)
          to_plot[page_num]['unified'].append(False)
          to_plot[page_num]['note'].append(config['plots'][section][_]['note'])
        tocentries[f"{section}: {', '.join(to_plot[page_num]['graphs'])}"] = page_num
        page_num += 1

  ####################################### Custom plots (e.g. JuMonC) ########################################
  # These plots are plotted into a unified figure in plotly, so they have to
  # be treated separate from to_plot here. They are plotted on the pdf the same way, but
  # to create a single/unified plotly figure, it can't be looped over the graphs
  to_plot_extra = {}
  for section in df_custom.keys():
    schema = data[config['plots'][section]['_section']]
    graphs = [_ for _ in schema['names'].split('::') if _]
    if len(graphs) != schema['numvars']:
      log.error(f"Number of graphs ({len(graphs)}) different than numvars ({schema['numvars']}) in custom section {section}! Skipping...")
      continue
    minimums = [float(_) if _ else None for _ in schema['minimums'].split('::')[:schema['numvars']]]
    maximums = [float(_) if _ else None for _ in schema['maximums'].split('::')[:schema['numvars']]]
    descs = [_ for _ in schema['descs'].split('::')[0:schema['numvars']]]
    to_plot_extra[section] = {}
    to_plot_extra[section]['type'] = section
    to_plot_extra[section]['data'] = df_custom[section]
    to_plot_extra[section]['graphs'] = graphs
    to_plot_extra[section]['headers'] = []
    to_plot_extra[section]['unit']   = []
    to_plot_extra[section]['cmap']   = []
    to_plot_extra[section]['lim']    = []
    to_plot_extra[section]['log']    = []
    to_plot_extra[section]['x']      = []
    to_plot_extra[section]['xlabel'] = []
    to_plot_extra[section]['y']      = []
    to_plot_extra[section]['ylabel'] = []
    to_plot_extra[section]['note']   = []
    to_plot_extra[section]['colorplot'] = []
    to_plot_extra[section]['unified'] = []
    to_plot_extra[section]['description'] = []
    # Looping over graphs defined in the custom section 
    for idx,_ in enumerate(graphs):
      # The header on the dat file uses a generic name, and not the real "name" of the graph
      to_plot_extra[section]['headers'].append(f"value{idx}")
      to_plot_extra[section]['unit'].append('') # Should we add units in the list of possible entries?
      to_plot_extra[section]['cmap'].append('cmc.hawaii')
      to_plot_extra[section]['lim'].append([minimums[idx], maximums[idx]])
      to_plot_extra[section]['log'].append(False)
      to_plot_extra[section]['colorplot'].append(True)
      to_plot_extra[section]['note'].append('')
      to_plot_extra[section]['unified'].append(True)
      to_plot_extra[section]['description'].append(descs[idx])
      to_plot_extra[section]['x'].append(config['plots'][section]['x']['header'] if ('x' in config['plots'][section] and 'header' in config['plots'][section]['x']) else config['plots']['x']['header'])
      to_plot_extra[section]['xlabel'].append(config['plots'][section]['x']['name'] if ('x' in config['plots'][section] and 'name' in config['plots'][section]['x']) else config['plots']['x']['name'] if 'name' in config['plots']['x'] else "")
      to_plot_extra[section]['y'].append(config['plots']['y']['header'])
      to_plot_extra[section]['ylabel'].append(config['plots'][section]['y']['name'] if ('y' in config['plots'][section] and 'name' in config['plots'][section]['y']) else config['plots']['y']['name'] if 'name' in config['plots']['y'] else "")


    config['plots'][section]['Custom'] = {}
    config['plots'][section]['Custom']['description'] = "User-defined graphs:\n{}".format('\n '.join([ f"{_}: {descs[idx]}" for idx,_ in enumerate(graphs) ]))
    tocentries[f"{section}: {', '.join(to_plot_extra[section]['graphs'])}"] = page_num
    page_num += 1

  ##########################################################################################################
  # Fixing missing sections by adding a '-' on the required quantities
  if 'fabric' not in data:
    data['fabric'] = {}
    for key in ['mbin_min','mbin_avg','mbin_max','mbout_min','mbout_avg','mbout_max','pckin_min','pckin_avg','pckin_max','pckout_min','pckout_avg','pckout_max']:
      data['fabric'][key] = '-'

  if 'fs' not in data:
    data['fs'] = {}
    for fs in ['home','project','scratch','fastdata']:
      for key in [f'fs_{fs}_Mbw_sum',f'fs_{fs}_Mbr_sum',f'fs_{fs}_MbwR_max',f'fs_{fs}_MbrR_max',f'fs_{fs}_ocR_max']:
        data['fs'][key] = '-'

  ####################################### Nodelist #########################################################
  # Nodelist color cycler
  config['appearance']['color_cycler'] = itertools.cycle(config['appearance']['colors_cmap'])

  nodedict = {}
  # Creating dictionary for each cpu
  cpulist = list(filter(None,data['job']['nodelist'].split(" ")))
  for cpu in cpulist:
    nodedict[cpu] = {}

  # Adding IC group (only elements that contain ':')
  if ('IC' in data) and ('icgroupmap' in data['IC']):
    icgroupmap = list(filter(lambda k: ':' in k,str(data['IC']['icgroupmap']).split(" ")))
  else:
    icgroupmap = []
  ics = {}
  for icgroup in icgroupmap:
    cpu,ic = icgroup.split(':')
    if ic in ics:
      color = ics[ic]
    else:
      ics[ic] = list(next(config['appearance']['color_cycler']))
      color = ics[ic]
    nodedict[cpu] = {"IC":{int(ic):color}}

  if gpus:
    # Adding GPUs and their specifications
    gpulist = list(filter(None,data['gpu']['gpulist'].split(" ")))
    gpuspec = list(filter(None,data['gpu']['gpuspec'].split("|")))
    for idx,gpu in enumerate(gpulist):
      cpu,gpuidx = gpu.split("_")
      try: # Deal with missing GPU specs
        nodedict[cpu][f"GPU{int(gpuidx)}"] = f"{gpuspec[idx].split(':')[1]}"
      except IndexError:
        nodedict[cpu][f"GPU{int(gpuidx)}"] = "-"

  # Setting up rectangles
  nl_config = {}
  nl_config['left'] = 0.05
  nl_config['right']= 0.95
  nl_config['top']=0.93
  nl_config['bottom']=0.04
  nl_config['hspace'] = 0.002
  nl_config['wspace'] = 0.002
  nl_config['per_line'] = (5 if gpus else 8)
  nl_config['wsize']=(nl_config['right']-nl_config['left']-(nl_config['per_line']-1)*nl_config['wspace'])/nl_config['per_line']
  nl_config['hsize']=(0.05 if gpus else 0.02)

  # If number of cpus/gpus is large, add a separate section for the nodelist
  # Otherwise, they will be written in the bottom of the first page
  if (gpus and num_cpus>2*nl_config['per_line']) or (not gpus and num_cpus>9*nl_config['per_line']):
    nl_config['firstpage']=False
    tocentries['Nodelist']=page_num
    page_num += (int(num_cpus/(17*nl_config['per_line']))+1 if gpus else int(num_cpus/(40*nl_config['per_line']))+1)
  else:
    # If nodelist in first page, change TOC item and re-sort it
    nl_config['firstpage']=True
    tocentries['Overview and Nodelist'] = tocentries.pop('Overview')
    tocentries = dict(sorted(tocentries.items(), key=lambda item: item[1]))
  ########################################### Finalization report ###########################################
  error_lines = []
  # Separating all the steps (if present)
  if ('rc' in data) and ('stepspec' in data['rc']):
    steps = re.findall(r'\((.*?)\)', data['rc']['stepspec'])
  else:
    steps = []

  # Storing information of different steps separately
  step_details = {}
  rows = []
  for step in steps:
    # Separating information of each step (name, rc, start, end, state)
    step_info=re.findall('(.+?)(:{2}|$)', step)
    # if step_info[0][0] =="job": continue # skipping step "job"
    for info in step_info:
      details = re.findall('(.*)=(.*)', info[0])
      if details == []:
        # Getting step name
        step_details['step'] = info[0]
      else:
        # Getting step information
        step_details[details[0][0]] = details[0][1]
    rows.append(list(step_details.values()))
  # Defining default values (for when when 'stepspec' is not present)
  config['timeline'] = {}
  config['timeline']['npages'] = 0
  config['timeline']['nsteps'] = 0
  config['timeline']['barsize'] = config['appearance']['max_bar_size']
  timeline_df = pd.DataFrame([])
  nsteps_last = 0
  # If data for steps is present
  if rows:
    timeline_df = pd.DataFrame(rows, columns=step_details.keys()).apply(pd.to_numeric,errors='ignore').fillna(0)
    if 'ntasks' in timeline_df:
      timeline_df['ntasks'] = timeline_df['ntasks'].astype('int')
    # Getting only the first 'max_steps_in_timeline' rows of dataframe (defined in the config file)
    if( 'max_steps_in_timeline' in config['appearance'] and config['appearance']['max_steps_in_timeline'] > -1 ):
      timeline_df = timeline_df.head(config['appearance']['max_steps_in_timeline'])
    config['timeline']['nsteps'] = len(timeline_df.index)
    # project end date
    # if timeline_df['end'].max() == -1:
    #   proj_end = datetime.datetime.timestamp(datetime.datetime.strptime(data['job']['updatetime'], '%Y-%m-%d %H:%M:%S'))
    # else:
    #   proj_end = timeline_df['end'].max()
    proj_end = datetime.datetime.timestamp(datetime.datetime.strptime(data['job']['updatetime'], '%Y-%m-%d %H:%M:%S'))
    timeline_df.loc[timeline_df['end']<0,'end'] = proj_end
    timeline_df['start_time'] = timeline_df['beg'].apply(lambda x: datetime.datetime.utcfromtimestamp(int(x)+config['appearance']['timezonegap'])) 
    timeline_df['end_time'] = timeline_df['end'].apply(lambda x: datetime.datetime.utcfromtimestamp(int(x+config['appearance']['timezonegap']))) 
    timeline_df['duration'] = timeline_df['end_time']-timeline_df['start_time']
    timeline_df[['color','edgecolor','colorhtml','edgecolorhtml']] = timeline_df['st'].apply(lambda x: add_color(x))
    # Sorting the dataframe
    timeline_df = pd.concat([timeline_df[timeline_df['step']=='job'],timeline_df[timeline_df['step']=='batch'],timeline_df[timeline_df['step']=='interactive'],timeline_df[(timeline_df['step']!='job') & (timeline_df['step']!='batch') & (timeline_df['step']!='interactive')].sort_values('step', key=lambda x: x.astype(int))],axis=0).reset_index(drop=True)
    # Calculating number of pages using configured max_timeline_steps_per_page
    config['timeline']['steps_per_page'] = config['appearance']['max_timeline_steps_per_page']
    config['timeline']['npages'] = int((config['timeline']['nsteps']-1)/config['timeline']['steps_per_page'])+1
    # Number of steps in the last page
    nsteps_last = (config['timeline']['nsteps']-1)%config['timeline']['steps_per_page']+1
    # Checking if this results in too few steps (as given in min_timeline_steps_last_page) for last page (>1)
    if (config['timeline']['npages']>1) and (0<nsteps_last<config['appearance']['min_timeline_steps_last_page']):
      # If it is, use one page less and distribute steps
      config['timeline']['npages'] = config['timeline']['npages']-1
      config['timeline']['steps_per_page'] = int((config['timeline']['nsteps']-1)/config['timeline']['npages'])+1
      # Number of steps in the last page
      nsteps_last = (config['timeline']['nsteps']-1)%config['timeline']['steps_per_page']+1
    # Calculating barsize
    config['timeline']['barsize'] = min(config['timeline']['barsize'],config['appearance']['max_timeline_size']/min(config['timeline']['nsteps'],config['timeline']['steps_per_page']))

    tocentries['Timeline']=page_num
    page_num += config['timeline']['npages']

    # Getting the maximum end_time as the end of the job (to fix wrong end times)
    data['job']['updatetime'] = timeline_df['end_time'].max().strftime('%Y-%m-%d %H:%M:%S')

  ############################################## Error Messages #############################################
  error_lines = []
  error_nodes = {}
  if('rc' in data) and (int(data['rc']['nummsgs']) != 0):
    config['error'] = True
    config['empty_error_page'] = False
    if 0.900 - min(nsteps_last*config['timeline']['barsize'],config['appearance']['max_timeline_size']) > config['appearance']['min_space_for_err']:
      config['empty_error_page'] = True
      page_num -= 1

    tocentries['Node System Error report']=page_num
    data['rc']['err_type'] = False
    if "oom-killer" in data['rc']['errmsgs']:
      data['rc']['err_type'] = r"(Out-of-memory)"
    if "nodeDownAlloc" in data['rc']['errmsgs']:
      data['rc']['err_type'] = r"(Node Error)"
    error_lines = data['rc']['errmsgs'].split("|")
    error_nodes = set(re.findall(r'\((.*?)\)', data['rc']['errmsgnodes']))
    if (len(error_nodes) != data['rc']['numerrnodes']):
      log.error(f"Number of error nodes ({data['rc']['numerrnodes']}) different than the number of nodes given: {error_nodes}")

    page_num += ceil((len(error_lines)+(config['timeline']['nsteps']+22 if config['empty_error_page'] else 0))/config['appearance']['max_lines_per_page'])
  else:
    config['error'] = False
  ###########################################################################################################
  # Total number of pages
  page_num -= 1

  # Output files:
  # output = f"{folder}/python_{data['files']['pdffile']}"
  output_pdf = f"{config['outfolder']}/{data['files']['pdffile']}"
  if config['html'] or config['gzip']: 
    output_html = f"{config['outfolder']}/{data['files']['htmlfile']}"

  # Getting time range of the job:
  time_range = [datetime.datetime.strptime(data['job']['starttime'], '%Y-%m-%d %H:%M:%S'),datetime.datetime.strptime(data['job']['updatetime'], '%Y-%m-%d %H:%M:%S')]

  # Creating PDF
  figs = {}
  with PdfPages(output_pdf) as pdf:

    ############################################################################
    # First page:
    # Also gets min and max date from average plot of first page
    first_page_html,overview_fig,navbar,nodelist_html = FirstPage.FirstPage(pdf,data,config,df,time_range,page_num,tocentries,num_cpus,num_gpus,finished,gpus,nl_config,nodedict,error_nodes)

    ############################################################################
    # Graphs
    for report in to_plot.values():
      figs.setdefault(report['type'].replace("\\",""),{})
      figs[report['type'].replace("\\","")].update(CreateReports.CreateFullReport(pdf,data,config,page_num,report,time_range))

    ############################################################################
    # Custom graphs (User-defined)
    for section in to_plot_extra.values():
      figs.setdefault(section['type'].replace("\\",""),{})
      figs[section['type'].replace("\\","")].update(CreateReports.CreateFullReport(pdf,data,config,page_num,section,time_range))
      figs[section['type'].replace("\\","")].update(CreateUnifiedPlotlyFig(data,config,section,time_range))

    ############################################################################
    # Nodelist:
    if not nl_config['firstpage']:
      nodelist_html = Nodelist.Nodelist(pdf,data,config,gpus,nl_config,nodedict,error_nodes,page_num)

    ############################################################################
    # Last pages:
    timeline_html,system_report_html = LastPages.LastPages(pdf,data,config,page_num,timeline_df,time_range,error_lines)

  ############################################################################
  if config['html'] or config['gzip']: 
    config['appearance']['jobid'] = data['job']['jobid'] # Job ID for title and filename
    config['appearance']['system'] = data['job']['system'].lower().replace('_',' ') # System for filename
    GenerateHTML.CreateHTML(config, 
                            figs, 
                            navbar=navbar, 
                            first=first_page_html, 
                            overview=overview_fig, 
                            nodelist=nodelist_html, 
                            timeline=timeline_html,
                            system_report=system_report_html, 
                            filename=output_html)
  # Moving files to final folder
  if config['move']:
    shutil.move(output_pdf, f"{folder}/{data['files']['pdffile']}")
    if config['html']: shutil.move(output_html, f"{folder}/{data['files']['htmlfile']}")
    if config['gzip']: shutil.move(f"{output_html}.gz", f"{folder}/{data['files']['htmlfile']}.gz")

  finish_job = time.time()

  log.info(f"{njob}/{total_jobs}: {job} processed in {finish_job - start_job:.2f}s")
  return
############################################################################


############################################################################
def process_plotlist(config,q):
  """
  Multiprocess generation of job reports' PDFs
  """

  # Lock to check if plotlist file exists
  counter = 0
  while True:
    if check_shutdown():
      return
    if all([os.path.exists(_) for _ in config['file']]):
      start_plotlist = time.time()
      break
    if (counter > 5):
      log.error(f"At least one file from {config['file']} not found for 1 min. Stopping script!")
      if(email): msg.send_email(semail,remail,f"At least one file from {config['file']} not found for 1 min. Stopping script!")
      exit()
    log.warning(f"At least one file from {config['file']} not found, waiting 10s")
    time.sleep(10)
    counter += 1

  # Getting list of json files with all running jobs (and finished in the last 30 min) to process
  # If config['json']=True, all files are already json 
  if config['json']:
    jobs = config['file']
  else:
    # If config['json']=False, it should include a plotlist file with all the json to process
    jobs = []
    for file in config['file']:
      # Giving also the possibility to add extra json files
      if file.endswith('json'):
        jobs += [file]
      else:
        with open(file,'r') as file:
          jobs += [config['appearance']['folder_prefix']+line.rstrip() for line in file if line[0] != '#']

  # Number of jobs in plotlist
  njobs = len(jobs)
  total_jobs = min(njobs,config['maxjobs'])

  if total_jobs==0: 
    log.warning(f"No jobs in plotlist file!")
    return

  # Create pool for dispatching work 
  global pool
  pool = mp.Pool(config['nprocs'], worker_init, [q,config['logging']['level']])

  log.info(f"Generating report of {total_jobs} jobs")

  njob = 0
  for job in jobs:
    njob += 1                      # FOR DEBUG 
    if njob > config['maxjobs']:   # FOR DEBUG 
      break                        # FOR DEBUG 
    pool.apply_async(ProcessReport, [njob,total_jobs,job,config], callback=check_shutdown_callback, error_callback=error_handler)

  pool.close()
  pool.join()

  finish_plotlist = time.time()
  used_procs = min(config['nprocs'],total_jobs)
  log.info(f"Current plotlist processed {total_jobs} jobs in {used_procs} processes, ended in {finish_plotlist - start_plotlist:.2f}s (Average of {used_procs*(finish_plotlist - start_plotlist)/total_jobs:.2f}s per job)")
  return


def parse_config_yaml(filename,expand_envvars=False):
  """
  YML configuration parser
  """
  with open(filename, 'r') as configyml:
    configyml = yaml.safe_load(configyml)
  if expand_envvars:
    for key,value in configyml.items():
      if isinstance(value,str):
        configyml[key] = os.path.expandvars(value)
  return configyml


def worker_init(q,level):
  """
  Initialize Handler for the queue in each worker/process
  """
  # all records from worker processes go to qh and then into q
  qh = QueueHandler(q)
  log = logging.getLogger('logger')
  log.setLevel(level)
  log.addHandler(qh)
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

def log_init(config):
  """
  Initialize logger and Multiprocessing Queue to "listen" to log messages
  (Adapted from: https://stackoverflow.com/a/45967068/3142385)
  """
  # Getting logger
  log = logging.getLogger('logger')
  log.setLevel(config['level'])

  # Setup handler: file (when configured) or stdout, stderr 
  if 'file' in config:
    fh = logging.FileHandler(config['file'], mode=config['filemode'])
    fh.setLevel(config['level'])
    fh.setFormatter(CustomFormatter(config['format'],datefmt=config['datefmt']))
    log.addHandler(fh)  # add the handler to the logger so records from this process are handled
    handler = [fh]
  elif ('logprefix' in config and config['logprefix']):
    oh = TimedRotatingFileHandler(config['logprefix']+".log",'midnight',1)
    oh.suffix = "%Y.%m.%d.log"
    oh.extMatch = re.compile(r"^.\d{4}.\d{2}.\d{2}.log$")
    oh.setLevel(config['level'])
    oh.setFormatter(CustomFormatter(config['format'],datefmt=config['datefmt']))
    oh.addFilter(_ExcludeErrorsFilter())
    log.addHandler(oh)  # add the handler to the logger so records from this process are handled

    eh = TimedRotatingFileHandler(config['logprefix']+".err",'midnight',1)
    eh.suffix = "%Y.%m.%d.errlog"
    eh.extMatch = re.compile(r"^.\d{4}.\d{2}.\d{2}.errlog$")
    eh.setLevel('ERROR')
    eh.setFormatter(CustomFormatter(config['format'],datefmt=config['datefmt']))
    log.addHandler(eh)  # add the handler to the logger so records from this process are handled
    handler = [oh,eh]
  else:
    oh = logging.StreamHandler(sys.stdout)
    oh.setLevel(config['level'])
    oh.setFormatter(CustomFormatter(config['format'],datefmt=config['datefmt']))
    oh.addFilter(_ExcludeErrorsFilter())
    log.addHandler(oh)  # add the handler to the logger so records from this process are handled

    eh = logging.StreamHandler(sys.stderr)
    eh.setLevel('ERROR')
    eh.setFormatter(CustomFormatter(config['format'],datefmt=config['datefmt']))
    log.addHandler(eh)  # add the handler to the logger so records from this process are handled
    handler = [oh,eh]

  # ql gets records from the queue and sends them to the handler
  q = mp.Queue()
  ql = QueueListener(q, *handler, respect_handler_level=True)
  ql.start()

  return ql, q


################################################################################
# MAIN PROGRAM:
################################################################################
def main():
  """
  Main program where deamon and child asynchronous processes are handled
  """
  mp.set_start_method('forkserver')
  global nerrors
  nerrors = 0

  # Parse arguments
  parser = argparse.ArgumentParser(description="JuRepTool")
  parser.add_argument("file", nargs="+", help="File including list of running and recently-finished jobs or JSON file of a job")
  parser.add_argument("--daemon", default=False, action="store_true" , help="Run as a 'daemon', i.e., in an infinite loop")
  parser.add_argument("--demo", default=False, action="store_true" , help="Run in 'demo' mode (hide usernames, project id and job names)")
  parser.add_argument("--nomove", default=False, action="store_true" , help="Don't copy files to final location")
  parser.add_argument("--nohtml", default=False, action="store_true" , help="Deactivate generation of HTML")
  parser.add_argument("--gzip", default=False, action="store_true" , help="Compress HTML using gzip")
  parser.add_argument("--plotlyjs", default='cdn', help="Location of the 'plotly.min.js' file (default: 'cdn')")
  parser.add_argument("--maxjobs", default=10000, type=int, help="Maximum number of jobs to process (default: MAXJOBS=10000)")
  parser.add_argument("--maxsec", default=0, type=int, help="Filter date range with maximum seconds range (default: no filter)")
  parser.add_argument("--shutdown", nargs="+", default=["./shutdown"], help="File(s) that triggers the script to shutdown")
  parser.add_argument("--nprocs", default=4, type=int, help="Number of process to run in parallel (default: NPROCS=4)")
  parser.add_argument("--loglevel", default=False, help="Select log level: 'DEBUG', 'INFO', 'WARNING', 'ERROR' (more to less verbose)")
  parser.add_argument("--logprefix", help="Prefix for the daily log and errlog files (default: None)")
  parser.add_argument("--configfolder", default=os.path.dirname(os.path.realpath(__file__))+"/../../configs/server/jureptool", help="Folder with YAML configuration files (default: src/../../configs/server/jureptool)")
  parser.add_argument("--outfolder", default="./results", help="Folder to store temporary and demo PDFs")
  parser.add_argument("--semail", default="", help="Sender email to use in case of errors (default: None)")
  parser.add_argument("--remail", default="", help="Receiver email to use in case of errors (default: None)")
  args = parser.parse_args()

  # Parsing configuration
  config = {}
  # Report appearance
  config['appearance'] = parse_config_yaml(f"{args.configfolder}/config.yml",expand_envvars=True)
  config['appearance']['color_cycler'] = None # Initializing
  config['appearance']['colors_cmap'] = colormaps[config['appearance']['colors']].colors
  config['appearance']['gradient'] = np.outer(np.arange(0, 1, 0.01), np.ones(1))
  config['appearance']['traffic_light_cmap'] = LinearSegmentedColormap.from_list("", ["tab:red","gold","tab:green"])
  config['appearance']['maxsec'] = args.maxsec
  if 'plotly_js' not in config['appearance']:
    config['appearance']['plotly_js'] = args.plotlyjs

  # Configuration
  config['file'] = []
  for file in args.file:
    config['file']+=glob.glob(file)
  config['json'] = False
  if all([_.endswith('json') for _ in config['file']]):
    config['json'] = True
  config['demo'] = args.demo
  config['html'] = not args.nohtml
  config['gzip'] = args.gzip
  config['move'] = not args.nomove
  config['maxjobs'] = args.maxjobs
  config['nprocs'] = args.nprocs
  config['outfolder'] = args.outfolder
  
  # Systems configurations
  config['system'] = parse_config_yaml(f"{args.configfolder}/system_info.yml")
  # Plots configurations
  config['plots'] = parse_config_yaml(f"{args.configfolder}/plots.yml")
  # Logger configuration
  config['logging'] = parse_config_yaml(f"{args.configfolder}/logging.yml")

  # Configuring the logger (level and format)
  if args.loglevel:
    config['logging']['level'] = args.loglevel
  if args.logprefix:
    config['logging']['logprefix'] = args.logprefix
  ql, q = log_init(config['logging'])
  global log
  log = logging.getLogger('logger')

  if not config['file']:
    log.error(f"No file {args.file} found. Stopping script!")
    exit()

  log.info(f"File(s) to process: {config['file']}")

  # Getting initial modification date of plotlist
  moddate = min([os.path.getmtime(_) for _ in config['file']])

  # Check if file was already processed
  try:
    with open("lastmod", 'r') as f:
      newmoddate = float(f.readline())
      if (newmoddate >= moddate):
        log.error(f"File(s) {config['file']} already processed. Stopping script!")
        exit()
  except FileNotFoundError:
    pass

  # Set shutdown file as global variable
  global shutdown_file
  shutdown_file = args.shutdown

  # Set variables to sent email
  global email
  email = False
  if args.semail and args.remail:
    email = True
    global semail,remail
    semail = args.semail
    remail = args.remail
  elif args.semail or args.remail:
    log.error("Email configuration requires both sender (--semail) and receiver email (--remail)")
    exit()

  # Infinite loop to process modified plotlist files (daemon mode)
  while True:

    process_plotlist(config,q)

    if not args.daemon:
      break

    # Lock to check date modification of plotlist file
    counter = 0
    while True:
      if check_shutdown():
        break
      if all([os.path.exists(_) for _ in config['file']]):
        newmoddate = min([os.path.getmtime(_) for _ in config['file']])
        if(newmoddate > moddate):
          log.info("Plotlist file(s) modified, processing new jobs")
          moddate = newmoddate
          break
        log.warning(f"Plotlist file(s) not modified (last modification on {time.ctime(moddate)}), waiting 10s")
      else:
        log.warning(f"Plotlist file(s) removed (last modification on {time.ctime(moddate)}), waiting 10s")

      if (counter > 5):
        log.error(f"Plotlist file(s) {config['file']} not found or modified for 1 min. Saving last processed modification and stopping script!")
        # Storing the modification date of last processed plotlists file to avoid reprocessing it
        with open("lastmod", 'w') as f:
          f.write(f"{moddate}")
        if(email): msg.send_email(semail,remail,f"Plotlist file(s) {config['file']} not found or modified for 1 min. Stopping script!")
        exit()
      time.sleep(10)
      counter += 1


    if check_shutdown():
      log.warning("Shutdown file found, stopping daemon")
      break


  ql.stop()
  if nerrors == 0:
    log.info("Finalized successfully!")
    exit(0)
  else:
    log.warning(f"Finalized with {nerrors} error(s)!")
    exit(1)


if __name__ == "__main__":
  main()

