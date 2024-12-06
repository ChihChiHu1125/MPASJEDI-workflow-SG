#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Get GFS analysis (0-h forecast) for cold start initial conditions

# Process arguments
# =================
## args
# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgWorkDir: my location
set ArgWorkDir = "$2"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/externalanalyses.csh
source config/tools.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
set prevValidDate = `$advanceCYMDH ${thisCycleDate} -6`

source ./bin/getCycleVars.csh

set ccyymmdd = `echo ${thisValidDate} | cut -c 1-8`
set ccyy = `echo ${thisValidDate} | cut -c 1-4`

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

if ( -e GETSUCCESS ) then
  echo "$0 (INFO): GETSUCCESS file already exists, exiting with success"
  echo "$0 (INFO): if regenerating the output files is desired, delete GETSUCCESS"

  date

  exit 0
endif

# ================================================================================================

set linkWPS = link_grib.csh
ln -sfv ${WPSBuildDir}/${linkWPS} .
rm -rf GRIBFILE.*

echo "Getting GFS analysis from RDA"
# RDA GFS forecasts directory
set GFSgribdirRDA = /glade/campaign/collections/rda/data/d084001
set res = 0p25

set gribFiles = ""
set thisWPSDate = ${thisValidDate}
set endWPSDate = `$advanceCYMDH ${thisValidDate} ${lbcExtendedHour}`
while ( ${thisWPSDate} <= ${endWPSDate} )

   set ccyymmdd = `echo ${thisWPSDate} | cut -c 1-8`
   set ccyy = `echo ${thisWPSDate} | cut -c 1-4`
   set fhour = 000
   set gribFile = ${ccyy}/${ccyymmdd}/gfs.${res}.${thisWPSDate}.f${fhour}.grib2
   echo $gribFile

   if ( ! -e ${GFSgribdirRDA}/${gribFile} ) then
     if ( ${lbcIntervalHour} <= 3) then
        set fhour = 003
     else
        set fhour = 006
     endif
     set prevWPSDate = `$advanceCYMDH ${thisWPSDate} -${fhour}`
     set ccyymmdd = `echo ${prevWPSDate} | cut -c 1-8`
     set ccyy = `echo ${prevWPSDate} | cut -c 1-4`
     set gribFile = ${ccyy}/${ccyymmdd}/gfs.${res}.${prevWPSDate}.f${fhour}.grib2
     if ( -e ${GFSgribdirRDA}/${gribFile} ) then
        set gribFiles = "${gribFiles} ${GFSgribdirRDA}/${gribFile}"
        echo ${gribFiles}
     endif
   else
     set gribFiles = "${gribFiles} ${GFSgribdirRDA}/${gribFile}"
     echo ${gribFiles}
   endif

   set thisWPSDate = `$advanceCYMDH ${thisWPSDate} +${lbcIntervalHour}`

end

# link ungribbed GFS
./${linkWPS} ${gribFile}

# check if the gribFile was linked
if ( ! -e "GRIBFILE.AAA") then
   echo "GRIBFILE.AAA is not in folder -- exiting"
   exit 1
endif

date

touch GETSUCCESS

exit 0
