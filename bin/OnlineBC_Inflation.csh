#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Apply online bias correction inflation for AHI cloudy-sky radiances
# Reads an inflation YAML and produces obsout_da_ahi-cld_himawari9_onlineBC_inflation.h5

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
      # output directory and file
      set outDir          = "${self_WorkDir}/${OutDBDir}"
      # CCH: For prior_anchor, obsout has _anc suffix (written by EnKFObserver_radiance); keep same suffix for outFile
      if ( "$ensembleOnlineBC" == True && "$EOBC_method" == prior_anchor ) then
        set outFile = "${outDir}/obsout_da_${instrument}_anc.h5"
      else
        set outFile = "${outDir}/obsout_da_${instrument}.h5"
      endif
      set satbiasInFile   = "${DAWorkDir}/${prevCycleDate}/${OutDBDir}/satbias_${instrument}.h5"
      set workYAML        = "${self_WorkDir}/oberr_inflation_onlineBC.yaml"

      # verify if input obsout file / satbias file exist:
      # CCH: For prior_anchor, EnKFObserver_radiance writes obsout with _anc suffix
      if ( "$ensembleOnlineBC" == True && "$EOBC_method" == prior_anchor ) then
        set inFile = "${outDir}/obsout_da_${instrument}_anc.h5"
      else
        set inFile = "${outDir}/obsout_da_${instrument}.h5"
      endif
      if ( ! -f ${inFile} ) then
        echo "ERROR in $0 : input obsout file not found: ${inFile}" > ./FAIL
        exit 1
      endif

      if ( ! -f ${satbiasInFile} ) then
        # set it to initial satbias file:
        set satbiasInFile = "${initialVARBCcoeff}/satbias_${instrument}.h5"
        echo "Use initial bias correction file ${satbiasInFile}"

        ln -sf "$satbiasInFile" "$outDir/satbias_${instrument}_initial.h5"

        if ( ! -f ${satbiasInFile} ) then
          echo "ERROR in $0 : input satbias file not found: ${satbiasInFile}" > ./FAIL
          exit 1
        endif
      endif

      # copy the python scripts for obs error inflation and its configuration file:
      cp $origin/tools/EnsembleOnlineBC/oberr_inflation_onlineBC.py ${self_WorkDir}/
      cp $origin/tools/EnsembleOnlineBC/oberr_inflation_onlineBC.yaml ${workYAML}

      # change the YAML for obs error inflation:
      # additional setup configs can be added below
      sed -i 's@obsout_infile:.*@obsout_infile: '"${inFile}"'@' ${workYAML}
      sed -i 's@satbias_infile:.*@satbias_infile: '"${satbiasInFile}"'@' ${workYAML}
      sed -i 's@obsout_outfile:.*@obsout_outfile: '"${outFile}"'@' ${workYAML}

      # implement the python script
      #/home/users/industry/nea/hucc/miniconda3/bin/python oberr_inflation_onlineBC.py --config ${workYAML}
      python oberr_inflation_onlineBC.py --config ${workYAML}

      # Check output
      # ============
      if ( ! -f ${outFile} ) then
        echo "ERROR in $0 : output file not created: ${outFile}" > ./FAIL
        exit 1
      endif

    endif
  end
end

echo "OnlineBC_Inflation completed successfully: ${outFile}"

date

exit 0
