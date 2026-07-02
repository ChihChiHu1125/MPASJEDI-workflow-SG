#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Calculate HBHT for AHI cloudy-sky radiances
# Reads YAML and produces HBHT.npy & HBHT.json

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
source config/auto/scenario.csh observations

set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

cd ${mainScriptDir}
setenv getObservationsOrNone "${getLocalOrNone}"
set key = instrumentsAllowingBiasCorrection
set $key = (`$getObservationsOrNone resources.${observations__resource}.${key}`)

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# cycle over sensors (that needs to be bias-corrected):
foreach instrument ($observers)
  foreach i ($instrumentsAllowingBiasCorrection)
    if ("$instrument" == "$i") then
      # input/output directory and file
      set obsoutDir       = "${self_WorkDir}/${OutDBDir}"
      set outFile         = "${obsoutDir}/HBHT_${instrument}.npy"
      set workYAML        = "${self_WorkDir}/compute_ensemble_HBHt.yaml"

      # verify if input obsout file / satbias file exist:
      set inFile = "${obsoutDir}/obsout_da_${instrument}.h5"
      if ( ! -f ${inFile} ) then
        echo "ERROR in $0 : input obsout file not found: ${inFile}" > ./FAIL
        exit 1
      endif

      # copy the python scripts for computing HBHT and its configuration file:
      cp $origin/tools/EnsembleOnlineBC/compute_ensemble_HBHt.py ${self_WorkDir}/
      cp $origin/tools/EnsembleOnlineBC/compute_ensemble_HBHt.yaml ${workYAML}

      # change the YAML:
      # input/output
      sed -i 's@obsout:.*@obsout: '"${inFile}"'@' ${workYAML}
      sed -i 's@hbht_output:.*@hbht_output: '"${outFile}"'@' ${workYAML}

      # horizontal localization:
      set horizontalLocalizationLengthscaleKm = `python -c "print(${horizontalLocalizationLengthscale} / 1000)"`
      sed -i 's@horizontal_scale:.*@horizontal_scale: '"${horizontalLocalizationLengthscaleKm}"'@' ${workYAML}

      # data selection 
      sed -i 's@  method:.*@  method: '"${onlineBCDataSelectionMethod}"'@' ${workYAML}
      sed -i 's@  cloud_diff_threshold:.*@  cloud_diff_threshold: '"${onlineBCDataSelectionCloudDiffThreshold}"'@' ${workYAML}

      # implement the python script
      python compute_ensemble_HBHt.py --config ${workYAML}

      # Check output
      # ============
      if ( ! -f ${outFile} ) then
        echo "ERROR in $0 : output file not created: ${outFile}" > ./FAIL
        exit 1
      endif

    endif
  end
end

echo "CalculateHBHT completed successfully: ${outFile}"

date

exit 0
