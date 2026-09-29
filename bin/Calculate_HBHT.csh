#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Estimate the ensemble HBH^T matrix for the ensembleOnlineBC 'prior' method
# Reads the obsout written by EnKFObserver_radiance and produces
# HBHT_{{instrument}}.npy / HBHT_{{instrument}}_meta.json

date

# Setup environment
# =================
source config/mpas/variables.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/enkf.csh
source config/auto/workflow.csh
source config/auto/naming.csh
source config/auto/model.csh
source config/auto/observations.csh

# getObservationsOrNone exposes the observations section of the config for run-time-dependent
# behaviors
source config/auto/scenario.csh observations
setenv getObservationsOrNone "${getLocalOrNone}"

set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# need to change to mainScriptDir for getObservationsOrNone to work
cd ${mainScriptDir}
set key = instrumentsAllowingBiasCorrection
set $key = (`$getObservationsOrNone resources.${observations__resource}.${key}`)

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# cycle over sensors that require ensemble online bias correction
foreach instrument ($observers)
  foreach i ($instrumentsAllowingBiasCorrection)
    if ("$instrument" == "$i") then
      # obsout written by EnKFObserver_radiance always carries the _anc suffix
      set obsoutDir = "${self_WorkDir}/${OutDBDir}"
      set inFile    = "${obsoutDir}/obsout_da_${instrument}_anc.h5"
      set outFile   = "${obsoutDir}/HBHT_${instrument}.npy"
      set workYAML  = "${self_WorkDir}/compute_ensemble_HBHt.yaml"

      if ( ! -f ${inFile} ) then
        echo "ERROR in $0 : input obsout file not found: ${inFile}" > ./FAIL
        exit 1
      endif

      # copy the python script and its configuration file to the working directory
      cp $origin/tools/EnsembleOnlineBC/compute_ensemble_HBHt.py ${self_WorkDir}/
      cp $origin/tools/EnsembleOnlineBC/compute_ensemble_HBHt.yaml ${workYAML}

      # input/output
      sed -i 's@obsout:.*@obsout: '"${inFile}"'@' ${workYAML}
      sed -i 's@hbht_output:.*@hbht_output: '"${outFile}"'@' ${workYAML}

      # horizontal localization: convert m -> km
      set horizontalLocalizationLengthscaleKm = `python -c "print(${horizontalLocalizationLengthscale} / 1000)"`
      sed -i 's@horizontal_scale:.*@horizontal_scale: '"${horizontalLocalizationLengthscaleKm}"'@' ${workYAML}

      # data selection
      sed -i 's@  method:.*@  method: '"${onlineBCDataSelectionMethod}"'@' ${workYAML}
      sed -i 's@  cloud_diff_threshold:.*@  cloud_diff_threshold: '"${onlineBCDataSelectionCloudDiffThreshold}"'@' ${workYAML}

      # run the python script
      python compute_ensemble_HBHt.py --config ${workYAML}

      # check output
      if ( ! -f ${outFile} ) then
        echo "ERROR in $0 : output file not created: ${outFile}" > ./FAIL
        exit 1
      endif

    endif
  end
end

echo "Calculate_HBHT completed successfully"

date

exit 0
