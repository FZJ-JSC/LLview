#!/usr/bin/bash
# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 
#    Filipe Guimarães (Forschungszentrum Juelich GmbH) 

usage() {
  echo -e "Usage:\n$0 [files to merge] [final file]"
}

if [ "$#" -le 1 ]; then
  echo -e "Illegal number of parameters. At least two files are required."
  usage
  exit 1
fi

# Cleaning file
rm -rf ${@: -1} 2>/dev/null

# Joining all into single file
for file in "${@:1:$#-1}"
do
  cat $file >> ${@: -1} 2>/dev/null
  echo "" >> ${@: -1}
done

exit

