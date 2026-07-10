#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Carry out LocalEnsembleDA (EnKF) for ensemble of first guess states

date

# Process arguments
# =================
## args
set ArgEnKFMode = "$1"

# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/enkf.csh
source config/auto/workflow.csh
source config/auto/naming.csh
source config/auto/model.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# EnKF: asObserver or asDiagOMA or Solver
if ( "$ArgEnKFMode" == "OMB" ) then
   set appName = "observerOMB"
   set myYAMLFile = ${appyaml}
else if ( "$ArgEnKFMode" == "OMA" ) then
   set appName = "observerOMA"
   set myYAMLFile = ${appyaml}
else if ( "$ArgEnKFMode" == "Solver" ) then
   set appName = "solver"
   set myYAMLFile = ${appyaml}
# CCH: prior_anchor modes
else if ( "$ArgEnKFMode" == "OMB_Anchor" ) then
   set appName = "observerOMB_anchor"
   set myYAMLFile = enkf_anchor.yaml
else if ( "$ArgEnKFMode" == "Solver_Anchor" ) then
   set appName = "solver_anchor"
   set myYAMLFile = enkf_anchor.yaml
else if ( "$ArgEnKFMode" == "OMB_Radiance" ) then
   set appName = "observerOMB_radiance"
   set myYAMLFile = enkf_radiance.yaml
else if ( "$ArgEnKFMode" == "Solver_Radiance" ) then
   set appName = "solver_radiance"
   set myYAMLFile = enkf_radiance.yaml
else
   echo "ERROR in ${ArgEnKFMode} in EnKF Mode" > ./FAIL
   exit 1
endif

# CCH: For Solver step, set openmpi (extended to cover Solver_Anchor and Solver_Radiance)
if ( "$ArgEnKFMode" == "Solver" || "$ArgEnKFMode" == "Solver_Anchor" || "$ArgEnKFMode" == "Solver_Radiance" ) then
   setenv OMP_NUM_THREADS ${solverThreads}
endif

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${EnKFBuildDir}
set myEXE = ${EnKFEXE}
set myYAML = ${self_WorkDir}/${myYAMLFile}

# ================================================================================================

## create and change to run directory
# CCH: OMB_Radiance uses a separate run_radiance/ directory to avoid clobbering anchor obs outputs
if ( "$ArgEnKFMode" == "OMB_Radiance" || "$ArgEnKFMode" == "Solver_Radiance" ) then
  set runDir = run_radiance
else
  set runDir = run
endif
if ( "$ArgEnKFMode" == "OMB" || "$ArgEnKFMode" == "OMB_Anchor" || "$ArgEnKFMode" == "OMB_Radiance" ) then
  rm -rf ${runDir}
  mkdir -p ${runDir}
endif
# go to the run directory
cd ${runDir}

if ( "$ArgEnKFMode" == "OMB" || "$ArgEnKFMode" == "OMB_Anchor" || "$ArgEnKFMode" == "OMB_Radiance" ) then
  ## link MPAS-Atmosphere lookup tables
  foreach fileGlob ($MPASLookupFileGlobs)
    ln -sfv ${MPASLookupDir}/*${fileGlob} .
  end

  ## link MP tables or nml
  if (${MicrophysicsOuter} == 'mp_thompson' ) then
    ln -svf $MPThompsonTablesDir/* .
  else if (${MicrophysicsOuter} == 'mp_nssl2m' ) then  
    ln -svf $ModelConfigDir/nssl_mp_params.in ./namelist.input
  endif

  ## link stream_list.atmosphere.* files
  ln -sfv ${self_WorkDir}/stream_list.atmosphere.* ./

  ## MPASJEDI variable configs
  foreach file ($MPASJEDIVariablesFiles)
    ln -sfv $ModelConfigDir/$file .
  end

  # Link+Run the executable
  # =======================
  ln -sfv ${myBuildDir}/${myEXE} ./

endif

# YAML setting
cp $myYAML ${appName}.yaml

if ( "$ArgEnKFMode" == "Solver" || "$ArgEnKFMode" == "Solver_Anchor" || "$ArgEnKFMode" == "Solver_Radiance" ) then
   sed -i 's@{{ensembleStateDir}}@'${CyclingDADir}'/'${backgroundSubDir}'@' ${appName}.yaml
   sed -i 's@{{ensembleStatePrefix}}@'${BGFilePrefix}'@' ${appName}.yaml
   sed -i 's@{{driver}}@asSolver@' ${appName}.yaml
   sed -i 's@{{ObsDataIn}}@ObsDataOut@' ${appName}.yaml
   sed -i 's@\ \+{{ObsDataOut}}@@' ${appName}.yaml
   sed -i 's@{{ObsOutSuffix}}@@' ${appName}.yaml
   sed -i 's@{{ObsSpaceDistribution}}@HaloDistribution@' ${appName}.yaml
   # CCH: Solver_Anchor writes analysis to an_anchor/ instead of the standard analysisSubDir
   if ( "$ArgEnKFMode" == "Solver_Anchor" ) then
      mkdir -p ${CyclingDADir}/an_anchor
      sed -i 's@'${WorkDir}'/'${analysisSubDir}'@'${WorkDir}'/an_anchor@g' ${appName}.yaml
   endif
else
   sed -i 's@{{driver}}@asObserver@' ${appName}.yaml
   sed -i 's@{{ObsSpaceDistribution}}@RoundRobinDistribution@' ${appName}.yaml
   sed -i 's@{{ObsDataIn}}@ObsDataIn@' ${appName}.yaml
   sed -i 's@{{ObsDataOut}}@obsdataout: *ObsDataOut@' ${appName}.yaml
   if ( "$ArgEnKFMode" == "OMA" ) then
      sed -i 's@{{ensembleStateDir}}@'${CyclingDADir}'/'${analysisSubDir}'@' ${appName}.yaml
      sed -i 's@{{ensembleStatePrefix}}@'${ANFilePrefix}'@' ${appName}.yaml
      sed -i 's@{{ObsOutSuffix}}@_ana@' ${appName}.yaml
      sed -i 's@*asGETKF@*asLETKF@' ${appName}.yaml
      # for ensembleOnlineBC prior method: redirect satbias to the posterior satbias file written by OnlineBCPriorUpdate
      if ( "$ensembleOnlineBC" == True && "$EOBC_method" == prior ) then
         sed -i 's@'${DAWorkDir}'/'${prevCycleDate}'/dbOut@'${CyclingDADir}'/dbOut@g' ${appName}.yaml
      endif
   # CCH: OMB_Radiance uses the anchor analysis (an_anchor/) as ensemble background
   else if ( "$ArgEnKFMode" == "OMB_Radiance" ) then
      sed -i 's@{{ensembleStateDir}}@'${CyclingDADir}'/an_anchor@' ${appName}.yaml
      sed -i 's@{{ensembleStatePrefix}}@'${ANFilePrefix}'@' ${appName}.yaml
      sed -i 's@{{ObsOutSuffix}}@@' ${appName}.yaml
   else
      # OMB and OMB_Anchor both use the forecast background
      sed -i 's@{{ensembleStateDir}}@'${CyclingDADir}'/'${backgroundSubDir}'@' ${appName}.yaml
      sed -i 's@{{ensembleStatePrefix}}@'${BGFilePrefix}'@' ${appName}.yaml
      sed -i 's@{{ObsOutSuffix}}@@' ${appName}.yaml
   endif
endif

# Run the EnKF exectuable
${mpiCommand} ./${myEXE} ${appName}.yaml ./${appName}.log >& ${appName}.log.all

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' ${appName}.log
if ( $status != 0 ) then
  echo "ERROR in $0 : enkf ${appName} failed" > ./FAIL
  exit 1
else
  rm ${appName}.log.0*
endif

# Remove obs-database output files
# ================================
# CCH: extended to cover Solver_Anchor and Solver_Radiance
if ("$retainObsFeedback" != "True" && ( "$ArgEnKFMode" == "Solver" || "$ArgEnKFMode" == "Solver_Anchor" || "$ArgEnKFMode" == "Solver_Radiance" ) ) then
  echo " ls ${self_WorkDir}/${OutDBDir}/"
  ls ${self_WorkDir}/${OutDBDir}/
  echo "rm ${self_WorkDir}/${OutDBDir}/${obsPrefix}*.h5"
	@@ -92,9 +154,6 @@ if ("$retainObsFeedback" != True) then
  rm ${self_WorkDir}/${OutDBDir}/${diagPrefix}*.nc4
endif

date

exit 0
