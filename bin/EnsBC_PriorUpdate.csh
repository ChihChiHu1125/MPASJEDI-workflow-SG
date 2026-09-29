#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Estimate updated satellite bias-correction coefficients for the ensembleOnlineBC
# 'prior' method, from the background (O-B) residuals of EnKFObserver_radiance and the
# ensemble HBH^T produced by Calculate_HBHT.csh.  Writes satbias_{{instrument}}.h5 into
# THIS cycle's dbOut, for use by (1) this cycle's EnKFDiagOMA diagnostic (redirected in
# EnKF.csh) and (2) next cycle's EnKFObserver/EnKFSolver_radiance.

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
      set outDir         = "${self_WorkDir}/${OutDBDir}"
      # obsout written by EnKFObserver_radiance always carries the _anc suffix
      set obsoutFile      = "${outDir}/obsout_da_${instrument}_anc.h5"
      set hbhtInFile       = "${outDir}/HBHT_${instrument}.npy"
      set satbiasInFile   = "${DAWorkDir}/${prevCycleDate}/${OutDBDir}/satbias_${instrument}.h5"
      set satbiasOutFile  = "${outDir}/satbias_${instrument}.h5"
      set csvOutFile      = "${outDir}/satbias_${instrument}.csv"
      set workYAML        = "${self_WorkDir}/mpas_jedi_online_satbias_estimator_prior.yaml"

      if ( ! -f ${obsoutFile} ) then
        echo "ERROR in $0 : input obsout file not found: ${obsoutFile}" > ./FAIL
        exit 1
      endif
      if ( ! -f ${hbhtInFile} ) then
        echo "ERROR in $0 : input HBHT file not found: ${hbhtInFile}" > ./FAIL
        exit 1
      endif

      # satbias_input: use previous cycle's; fall back to initial if not found
      if ( ! -f ${satbiasInFile} ) then
        set satbiasInFile = "${initialVARBCcoeff}/satbias_${instrument}.h5"
        echo "WARNING: previous cycle satbias not found, using initial: ${satbiasInFile}"
      endif

      # copy the python script and its configuration file to the working directory
      cp $origin/tools/EnsembleOnlineBC/mpas_jedi_online_satbias_estimator_prior.py ${self_WorkDir}/
      cp $origin/tools/EnsembleOnlineBC/mpas_jedi_online_satbias_estimator_prior.yaml ${workYAML}

      # update YAML paths (obsout is a list -- note the "    - " prefix in the YAML)
      sed -i 's@    - .*@    - '"${obsoutFile}"'@' ${workYAML}
      sed -i 's@hbht_input:.*@hbht_input:  '"${hbhtInFile}"'@' ${workYAML}
      sed -i 's@satbias_input:.*@satbias_input:  '"${satbiasInFile}"'@' ${workYAML}
      sed -i 's@satbias_output:.*@satbias_output: '"${satbiasOutFile}"'@' ${workYAML}
      sed -i 's@csv_output:.*@csv_output: '"${csvOutFile}"'@' ${workYAML}

      sed -i 's@inflation_factor:.*@inflation_factor: '"${onlineBCInflationFactor}"'@' ${workYAML}
      sed -i 's@  method:.*@  method: '"${onlineBCDataSelectionMethod}"'@' ${workYAML}
      sed -i 's@  cloud_diff_threshold:.*@  cloud_diff_threshold: '"${onlineBCDataSelectionCloudDiffThreshold}"'@' ${workYAML}

      # run the satbias estimator
      python mpas_jedi_online_satbias_estimator_prior.py --config ${workYAML}

      # check output
      if ( ! -f ${satbiasOutFile} ) then
        echo "ERROR in $0 : satbias output not created: ${satbiasOutFile}" > ./FAIL
        exit 1
      endif

    endif
  end
end

echo "EnsBC_PriorUpdate completed successfully"

date

exit 0
