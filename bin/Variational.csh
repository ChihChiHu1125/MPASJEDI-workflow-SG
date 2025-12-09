#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Carry out variational minimization for single first guess state
# ARGUMENTS:
# ArgMember - member index among nMembers

date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

## arg checks
set test = `echo $ArgMember | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgMember < 1 ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be > 0" > ./FAIL
  exit 1
endif

# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/tools.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/members.csh
source config/auto/variational.csh
source config/auto/workflow.csh
source config/auto/model.csh
source config/auto/naming.csh
source config/auto/observations.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${VariationalBuildDir}
set myEXE = ${VariationalEXE}
set myYAML = ${self_WorkDir}/${YAMLPrefix}${ArgMember}.yaml

if ( $ArgMember > $nMembers ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be <= nMembers ($nMembers)" > ./FAIL
  exit 1
endif

# Remove old netcdf lock files
rm *.nc*.lock
rm */*.nc*.lock

# ================================================================================================

## create then move to member-specific run directory
set memDir = `${memberDir} 2 ${ArgMember} "${flowMemFmt}"`
set runDir = run${memDir}
rm -r ${runDir}
mkdir -p ${runDir}
cd ${runDir}

## link MPAS-Atmosphere lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

if (${MicrophysicsOuter} == 'mp_thompson' ) then
  ln -svf $MPThompsonTablesDir/* .
endif

if (${MicrophysicsOuter} == 'mp_nssl2m' ) then
  ln -svf $ModelConfigDir/nssl_mp_params.in ./namelist.input
endif

## link stream_list.atmosphere.* files
ln -sfv ${self_WorkDir}/stream_list.atmosphere.* ./

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv $ModelConfigDir/$file .
end

# Determine whether to apply blending (Only support deterministic DA now)
set blending = False
@ hh_int = $hh + 0   
if ( "$nMembers" == "1" && "$useBlending" == "True" ) then
    @ mod =$hh_int % $blendingInterval
    if ( $mod == 0 ) then
        set blending = True
    endif
endif

# Apply Blending to background
if ("$blending" == True && "${blendingTarget}" == "background") then
    echo "apply blending to MPAS forecast"
    cp ${self_WorkDir}/${backgroundSubDir}/${BGFilePrefix}.$thisMPASFileDate.nc ${self_WorkDir}/${backgroundSubDir}/${BGFilePrefix}.$thisMPASFileDate.nc.bak
    set large_scale_file = `echo "${blendingLargeScaleFile}" \
          | sed 's@{{thisMPASFileDate}}@'${thisMPASFileDate}'@' \
          | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
          | sed 's@{{nCellsOuter}}@'${nCellsOuter}'@' \
          | sed 's@{{meshRatioOuter}}@'${meshRatioOuter}'@' \
          `
    set blending_arg1 = "${self_WorkDir}/blending"
    set blending_arg2 = "${large_scale_file}"
    set blending_arg3 = "${self_WorkDir}/${backgroundSubDir}/${BGFilePrefix}.$thisMPASFileDate.nc.bak"
    set blending_arg4 = "${self_WorkDir}/${backgroundSubDir}/${BGFilePrefix}.$thisMPASFileDate.nc"

    cd ${mainScriptDir}
    ${mainScriptDir}/bin/Blending.csh ${blending_arg1} ${blending_arg2} ${blending_arg3} ${blending_arg4}
    cd ${self_WorkDir}/${runDir}
endif

# Link+Run the executable
# =======================
ln -sfv ${myBuildDir}/${myEXE} ./

sed -i 's@{{ObsDataIn}}@ObsDataIn@' $myYAML
sed -i 's@{{ObsDataOut}}@obsdataout: *ObsDataOut@' $myYAML
sed -i 's@{{ObsOutSuffix}}@@' $myYAML

if ( $?numProcessors && "$numProcessors" != "None" ) then
  mpiexec -n ${numProcessors} ./${myEXE} $myYAML ./jedi.log >& jedi.log.all
else
  ${mpiCommand} ./${myEXE} $myYAML ./jedi.log >& jedi.log.all
endif

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  echo "ERROR in $0 : jedi application failed" > ./FAIL
  exit 1
endif

# Apply Blending to analysis
if ("$blending" == True && "${blendingTarget}" == "analysis") then      
   echo "apply blending to MPAS-JEDI analysis"
   cp ${self_WorkDir}/${analysisSubDir}/${ANFilePrefix}.$thisMPASFileDate.nc ${self_WorkDir}/${analysisSubDir}/${ANFilePrefix}.$thisMPASFileDate.nc.bak
   set large_scale_file = `echo "${blendingLargeScaleFile}" \
          | sed 's@{{thisMPASFileDate}}@'${thisMPASFileDate}'@' \
          | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
          | sed 's@{{nCellsOuter}}@'${nCellsOuter}'@' \
          | sed 's@{{meshRatioOuter}}@'${meshRatioOuter}'@' \
          `
   set blending_arg1 = "${self_WorkDir}/blending" 
   set blending_arg2 = "${large_scale_file}"
   set blending_arg3 = "${self_WorkDir}/${analysisSubDir}/${ANFilePrefix}.$thisMPASFileDate.nc.bak"
   set blending_arg4 = "${self_WorkDir}/${analysisSubDir}/${ANFilePrefix}.$thisMPASFileDate.nc"

   cd ${mainScriptDir}
   ${mainScriptDir}/bin/Blending.csh ${blending_arg1} ${blending_arg2} ${blending_arg3} ${blending_arg4}      
   cd ${self_WorkDir}
endif

# ================================================================================================

# Remove obs-database output files
# ================================
if ("$retainObsFeedback" != True) then
  set memDir = `${memberDir} $nMembers $ArgMember`
  echo "ls ${self_WorkDir}/${OutDBDir}${memDir}/"
  ls ${self_WorkDir}/${OutDBDir}${memDir}/
  echo "rm ${self_WorkDir}/${OutDBDir}${memDir}/${obsPrefix}*.h5"
  rm ${self_WorkDir}/${OutDBDir}${memDir}/${obsPrefix}*.h5
  echo "rm ${self_WorkDir}/${OutDBDir}${memDir}/${geoPrefix}*.nc4"
  rm ${self_WorkDir}/${OutDBDir}${memDir}/${geoPrefix}*.nc4
  echo "rm ${self_WorkDir}/${OutDBDir}${memDir}/${diagPrefix}*.nc4"
  rm ${self_WorkDir}/${OutDBDir}${memDir}/${diagPrefix}*.nc4
endif

# Remove netcdf lock files
rm *.nc*.lock
rm */*.nc*.lock

# Remove copies of templated fields files for inner loop
if ("${TemplateFieldsFileInner}" != "${TemplateFieldsFileOuter}") then
  echo "rm ${TemplateFieldsFileInner}*"
  rm ${TemplateFieldsFileInner}*
endif

date

exit 0
