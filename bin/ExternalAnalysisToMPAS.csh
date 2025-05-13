#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Process arguments
# =================
## args
# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgWorkDir: my location
set ArgWorkDir = "$2"

# ArgFilePrefix: prefix for output file
set ArgFilePrefix = "$3"

# ArgType: type of horizontal mesh
set ArgType = "$4"

# ArgExternalAnalysesDir: location of external analyses
set ArgExternalAnalysesDir = "$5"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/environmentJEDI.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/externalanalyses.csh
source config/auto/model.csh
source config/auto/invariantstream.csh
source config/tools.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`

# For regional DA lbcs
setenv lastMPASFcstDate "`$advanceCYMDH ${thisValidDate} ${lbcExtendedHour}`"
set yye = `echo ${lastMPASFcstDate} | cut -c 1-4`
set mme = `echo ${lastMPASFcstDate} | cut -c 5-6`
set dde = `echo ${lastMPASFcstDate} | cut -c 7-8`
set hhe = `echo ${lastMPASFcstDate} | cut -c 9-10`
set lastMPASNamelistDate = ${yye}-${mme}-${dde}_${hhe}:00:00

set lbcIntervalSeconds = `expr $lbcIntervalHour \* 3600`

source ./bin/getCycleVars.csh

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
set ExternalAnalysesDir = ${ExperimentDirectory}/`echo "$ArgExternalAnalysesDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

# only need to continue if output file does not already exist
set outputFile = $ArgFilePrefix.$thisMPASFileDate.nc

if ( -e $outputFile ) then
  if ( -e CONVERTSUCCESS ) then
    echo "$0 (INFO): outputFile ($outputFile) and CONVERTSUCCESS file already exist, exiting with success"
    echo "$0 (INFO): if regenerating the output outputFile is desired, delete CONVERTSUCCESS"

    date

    exit 0
  endif

  rm $outputFile
endif

# ================================================================================================
## link ungribbed files
ln -sfv ${ExternalAnalysesDir}/${externalanalyses__UngribPrefix}* ./

if ( $ArgType == "Outer" ) then
  set meshRatio = $meshRatioOuter
  set meshMode = $meshModeOuter
  set meshNCells = $nCellsOuter
else
  set meshRatio = $meshRatioInner
  set meshMode = $meshModeInner
  set meshNCells = $nCellsInner
endif

## link MPAS mesh graph info
rm ./x${meshRatio}.${meshNCells}.graph.info*
ln -sfv $GraphInfoDir/x${meshRatio}.${meshNCells}.graph.info* .

## Link MPAS invariant field
if ( $ArgType == "Outer" ) then
   ln -sfv $InvariantFieldsDirOuter/$InvariantFieldsFileOuter .
else
   ln -sfv $InvariantFieldsDirInner/$InvariantFieldsFileInner .
endif

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  rm ./*${fileGlob}
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## copy/modify dynamic streams file
rm ${StreamsFileInit}
cp -v $ModelConfigDir/initic/${StreamsFileInit} .
sed -i 's@{{nCells}}@'${meshNCells}'@' ${StreamsFileInit}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFileInit}
sed -i 's@{{meshRatio}}@'${meshRatio}'@' ${StreamsFileInit}
sed -i 's@{{lbcIntervalHours}}@3@' ${StreamsFileInit}

## copy/modify dynamic namelist
rm ${NamelistFileInit}
cp -v $ModelConfigDir/initic/${NamelistFileInit} .
sed -i 's@{{InitCase}}@7@' $NamelistFileInit
sed -i 's@{{StartTime}}@'${thisMPASNamelistDate}'@' $NamelistFileInit
sed -i 's@{{StopTime}}@'${thisMPASNamelistDate}'@' $NamelistFileInit
sed -i 's@{{LBCIntervalSeconds}}@21600@' $NamelistFileInit
sed -i 's@{{nCells}}@'${meshNCells}'@' $NamelistFileInit
sed -i 's@{{meshRatio}}@'${meshRatio}'@' $NamelistFileInit
sed -i 's@{{UngribPrefix}}@'${externalanalyses__UngribPrefix}'@' $NamelistFileInit
if ( ${meshMode} == "Regional" ) then
   sed -i 's@{{BlendBdyTerrain}}@true@' $NamelistFileInit
else
   sed -i 's@{{BlendBdyTerrain}}@false@' $NamelistFileInit
endif

# Run the executable
# ==================
rm ./${InitEXE}
ln -sfv ${InitBuildDir}/${InitEXE} ./
${mpiCommand} ./${InitEXE}

# Check status
# ============
grep "Finished running the init_${MPASCore} core" log.init_${MPASCore}.0000.out
if ( $status != 0 ) then
  rm $outputFile
  echo "ERROR in $0 : MPAS-init IC failed" > ./FAIL
  exit 1
endif

#### Next steps, will generate LBC for regional mode.
if ( ${meshMode} == "Regional" ) then
   ## copy/modify dynamic streams file
   mv ${StreamsFileInit} ${StreamsFileInit}.IC
   cp -v $ModelConfigDir/initic/${StreamsFileLBC} ./${StreamsFileInit}
   sed -i 's@{{nCells}}@'${meshNCells}'@' ${StreamsFileInit}
   sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFileInit}
   sed -i 's@{{meshRatio}}@'${meshRatio}'@' ${StreamsFileInit}
   sed -i 's@{{lbcIntervalHours}}@'${lbcIntervalHour}'@' ${StreamsFileInit}

   ## copy/modify dynamic namelist
   mv ${NamelistFileInit} ${NamelistFileInit}.IC
   cp -v $ModelConfigDir/initic/${NamelistFileInit} $NamelistFileInit
   sed -i 's@{{InitCase}}@9@' $NamelistFileInit
   sed -i 's@{{StartTime}}@'${thisMPASNamelistDate}'@' $NamelistFileInit
   sed -i 's@{{StopTime}}@'${lastMPASNamelistDate}'@' $NamelistFileInit
   sed -i 's@{{LBCIntervalSeconds}}@'${lbcIntervalSeconds}'@' $NamelistFileInit
   sed -i 's@{{nCells}}@'${meshNCells}'@' $NamelistFileInit
   sed -i 's@{{meshRatio}}@'${meshRatio}'@' $NamelistFileInit
   sed -i 's@{{UngribPrefix}}@'${externalanalyses__UngribPrefix}'@' $NamelistFileInit
   sed -i 's@{{BlendBdyTerrain}}@true@' $NamelistFileInit

   # Run the executable
   # ==================
   ${mpiCommand} ./${InitEXE}   

   # Check status
   # ============
   grep "Finished running the init_${MPASCore} core" log.init_${MPASCore}.0000.out
   if ( $status != 0 ) then
      rm $outputFile
      echo "ERROR in $0 : MPAS-init LBCs failed" > ./FAIL
      exit 1
   else
      mv ${StreamsFileInit} ${StreamsFileInit}.LBC
      mv ${NamelistFileInit} ${NamelistFileInit}.LBC
   endif
endif

date

touch CONVERTSUCCESS

exit 0
