#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# Process arguments
# =================
# ArgState: str, ensemble background or analysis
set ArgState = "$1"

# ArgContrlMember: integer, index of control member
set ArgContrlMember = "$2"

# ArgRecenterMode: "blending", "coupled"
set ArgRecenterMode = "$3"

# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/tools.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/invariantstream.csh
source config/auto/${ArgDAmethod}.csh
source config/auto/workflow.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

if (${nMembers} == 1) then
  echo "$0 (INFO): For single member, no need to run recenter"
  exit 0
endif

if ( ${ArgRecenterMode} == "blending" ) then
  @ hh_int = $hh + 0
  @ interval = ${blendingInterval} + 0
  @ mod = $hh_int % $interval
  if ( $mod -gt 0 ) then
    echo "$0 (INFO): For blending, only works at every ${blendingInterval} hours"
    exit 0
  endif
endif

if ( $ArgState == "background" ) then
  set self_WorkDir = ${CyclingDAInDir}/recenter
  set ensStateDir = ${CyclingDAInDir} 
  set ensStatePrefix = ${BGFilePrefix}
  set recenterStateDir = ${CyclingDAInDir}
  set recenterStatePrefix = ${BGFilePrefix}
  set RecenterFile = ${MeanBackgroundDirs[1]}/${BGFilePrefix}.$thisMPASFileDate.nc
else
  set self_WorkDir = ${CyclingDAOutDir}/recenter
  set ensStateDir = ${CyclingDAOutDir}
  set ensStatePrefix = ${ANFilePrefix}
  set recenterStateDir = ${CyclingDAOutDir}
  set recenterStatePrefix = ${ANFilePrefix}
  set RecenterFile = ${MeanAnalysisDirs[1]}/${ANFilePrefix}.$thisMPASFileDate.nc
endif

# Working directory
mkdir -p ${self_WorkDir} && cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${ensRecenterBuildDir}
set myEXE = ${ensRecenterExe}
set appyaml = ensRecenter.yaml
set myYAML = ${self_WorkDir}/${appyaml}

# ===================================================
## copy invariant fields
rm ${localInvariantFieldsPrefix}*.nc
set localInvariantFieldsFile = ${localInvariantFieldsFileEnsemble}
set InvariantFieldsFile = ${InvariantFieldsDirEnsemble}/${InvariantFieldsFileEnsemble}
rm ${localInvariantFieldsFile}
ln -sfv ${InvariantFieldsFile} ${localInvariantFieldsFile}

# ====================
# Model-specific files
# ====================
## link MPAS mesh graph info
ln -sfv $GraphInfoDir/x1.${nCellsEnsemble}.graph.info* .

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## link/copy stream_list/streams configs
foreach staticfile ( \
stream_list.${MPASCore}.background \
stream_list.${MPASCore}.analysis \
stream_list.${MPASCore}.ensemble \
stream_list.${MPASCore}.control \
)
  ln -sfv $ModelConfigDir/ensRecenter/$staticfile .
end

rm ${StreamsFile}
cp -v $ModelConfigDir/ensRecenter/${StreamsFile} .
sed -i 's@{{nCells}}@'${nCellsEnsemble}'@' ${StreamsFile}
sed -i 's@{{TemplateFieldsPrefix}}@'${self_WorkDir}'/'${TemplateFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{InvariantFieldsPrefix}}@'${self_WorkDir}'/'${localInvariantFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFile}

# determine analysis output precision
ncdump -h ${RecenterFile} | grep uReconstruct | grep double
if ($status == 0) then
  set analysisPrecision=double
else
  ncdump -h ${RecenterFile} | grep uReconstruct | grep float
  if ($status == 0) then
    set analysisPrecision=single
  else
    echo "ERROR in $0 : cannot determine analysis precision" > ./FAIL
    exit 1
  endif
endif
sed -i 's@{{analysisPRECISION}}@'${analysisPrecision}'@' ${StreamsFile}

## copy/modify dynamic namelist
rm $NamelistFile
cp -v $ModelConfigDir/ensRecenter/${NamelistFile} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFile
sed -i 's@blockDecompPrefix@'${self_WorkDir}'/x'${meshRatioEnsemble}'.'${nCellsEnsemble}'@' ${NamelistFile}
sed -i 's@modelDT@'${TimeStepEnsemble}'@' $NamelistFile
sed -i 's@numberOfSubSteps@'$NumberOfSubStepsEnsemble'@' $NamelistFile
sed -i 's@dynamicsSplitSteps@'$DynamicsSplitStepsEnsemble'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${DiffusionLengthScaleEnsemble}'@' $NamelistFile
sed -i 's@apvmUpwinding@'${ApvmUpwindingEnsemble}'@' $NamelistFile
sed -i 's@configZd@'$ConfigZdEnsemble'@' $NamelistFile
if ( $meshModeEnsemble == "Regional" ) then
  sed -i 's@applyLBCs@true@' $NamelistFile
else
  sed -i 's@applyLBCs@false@' $NamelistFile
endif

## modify namelist physics
sed -i 's@radtlwInterval@'${RadiationLWIntervalEnsemble}'@' $NamelistFile
sed -i 's@radtswInterval@'${RadiationSWIntervalEnsemble}'@' $NamelistFile
sed -i 's@physicsSuite@'${PhysicsSuiteEnsemble}'@' $NamelistFile
sed -i 's@micropScheme@'${MicrophysicsEnsemble}'@' $NamelistFile
sed -i 's@convectionScheme@'${ConvectionEnsemble}'@' $NamelistFile
sed -i 's@pblScheme@'${PBLEnsemble}'@' $NamelistFile
sed -i 's@gwdoScheme@'${GwdoEnsemble}'@' $NamelistFile
sed -i 's@radtCldScheme@'${RadiationCloudEnsemble}'@' $NamelistFile
sed -i 's@radtLWScheme@'${RadiationLWEnsemble}'@' $NamelistFile
sed -i 's@radtSWScheme@'${RadiationSWEnsemble}'@' $NamelistFile
sed -i 's@sfcLayerScheme@'${SfcLayerEnsemble}'@' $NamelistFile
sed -i 's@lsmScheme@'${LSMEnsemble}'@' $NamelistFile

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv $ModelConfigDir/$file .
end

# =============
# Generate yaml
# =============
## Copy jedi/applications yaml
set thisYAML = orig.yaml
cp -v ${ConfigDir}/jedi/applications/${appyaml} $thisYAML

## streams
sed -i 's@{{EnsembleStreamsFile}}@'${self_WorkDir}'/'${StreamsFile}'@' $thisYAML

## namelist
sed -i 's@{{EnsembleNamelistFile}}@'${self_WorkDir}'/'${NamelistFile}'@' $thisYAML

## revise current date
sed -i 's@{{thisISO8601Date}}@'${thisISO8601Date}'@g' $thisYAML

# use one of the analyses as the TemplateFieldsFileOuter
ln -sfv ${RecenterFile} ${TemplateFieldsFileOuter}

# Variables necessary
set StateVariables = ( \
  $StandardStateVariables \
  $MPASHydroStateVariables \
)
set VarSub = ""
foreach var ($StateVariables)
  set VarSub = "$VarSub$var,"
end
# remove trailing comma
set VarSub = `echo "$VarSub" | sed 's/.$//'`
sed -i 's@{{RecenterVariables}}@'$VarSub'@' $thisYAML

## file naming
sed -i 's@{{RecenterFile}}@'${RecenterFile}'@g' $thisYAML
sed -i 's@{{ensStateDir}}@'${memberPrefix}'@g' $thisYAML
sed -i 's@{{ensStatePrefix}}@'${ensStatePrefix}'@g' $thisYAML
sed -i 's@{{EnsembleNumber}}@'${nMembers}'@g' $thisYAML
sed -i 's@{{recenterStateDir}}@'${recenterStateDir}'@g' $thisYAML
sed -i 's@{{recenterStatePrefix}}@'${recenterStatePrefix}'@g' $thisYAML
set prevYAML = $thisYAML

## state and analysis variable configs
mv $prevYAML $myYAML

# Run the executable
# ==================
ln -sfv ${myBuildDir}/${myEXE} ./
${mpiCommand} ./${myEXE} $myYAML ./jedi.log >& jedi.log.all

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  echo "ERROR in $0 : jedi application failed" > ./FAIL
  exit 1
else
  rm jedi.log.0*
endif

date

exit 0
