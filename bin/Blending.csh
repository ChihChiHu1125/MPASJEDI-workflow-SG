#!/bin/csh -f

# (C) Copyright 2025 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# ArgDAmethod: to determine whether it is variational or EnKF method
set ArgDAmethod = "$1"

# ArgMemberIndex: index of the ensemble member (not work for deterministic DA)
set ArgMemberIndex = "$2"

# Env. setup
source config/environmentBlending.csh
source config/auto/build.csh
source config/auto/model.csh
source config/auto/${ArgDAmethod}.csh
source config/tools.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hour = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hour}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# determine whether to apply Blending
@ hh = $hour + 0
@ mod =$hh % $blendingInterval
if ( $mod > 0 ) then
  echo "$0 (INFO): For blending, only works at every ${blendingInterval} hours"
  exit 0
endif

if ( ${thisCycleDate} == ${nextFirstCycleDate} ) then
  if ( ${blendingFileFcstLength} > 0 && ${blendingTarget} =~ "background*" ) then
    echo "$0 (INFO): For the first DA cycle, background blending will not be applied when large-scale states not from analysis"
    exit 0
  endif
endif

# Main working directory
set WorkingDir = ${CyclingDADir}/blending
if ( ${ArgMemberIndex} > 0 ) then
  set memDir = `${memberDir} $nMembers $ArgMemberIndex`
  set WorkDir = ${WorkingDir}/${memDir}
else
  set WorkDir = ${WorkingDir}
endif

# Create and direct to WorkDir 
echo "WorkDir = ${WorkDir}/"
mkdir -p ${WorkDir}
cd ${WorkDir}

# large-scale file
setenv blendingCycleDate "`$advanceCYMDH ${thisCycleDate} -${blendingFileFcstLength}`"
if ( ${ArgDAmethod} == "enkf" && ( ${blendingTarget} == "background" || ${blendingTarget} == "analysis" ) ) then
  set indexOfEnsemble = `printf "%0${numDigitsOfBlendingFile}d" $ArgMemberIndex`
  set large_scale_file = `echo "$blendingLargeScaleFile" | sed \
    -e "s@{{thisMPASFileDate}}@$thisMPASFileDate@g" \
    -e "s@{{blendingCycleDate}}@$blendingCycleDate@g" \
    -e "s@{{nCellsOuter}}@$nCellsOuter@g" \
    -e "s@{{meshRatioOuter}}@$meshRatioOuter@g" \
    -e "s@{{indexOfEnsemble}}@$indexOfEnsemble@g"`
else
  set large_scale_file = `echo "$blendingLargeScaleFile" | sed \
    -e "s@{{thisMPASFileDate}}@$thisMPASFileDate@g" \
    -e "s@{{blendingCycleDate}}@$blendingCycleDate@g" \
    -e "s@{{nCellsOuter}}@$nCellsOuter@g" \
    -e "s@{{meshRatioOuter}}@$meshRatioOuter@g"`
endif

if ( ! -f ${large_scale_file} ) then
  echo "Blending failed: large scale file $large_scale_file not found" >> ./BLENDING_FAILED
  exit 9
endif

# small-scale file
if ( ${ArgDAmethod} == "enkf" && ${blendingTarget} == "backgroundMean" ) then
  if ( -f ${MeanBackgroundDirs[1]}/${FCFilePrefix}.${thisMPASFileDate}.nc ) then 
    cp ${MeanBackgroundDirs[1]}/${FCFilePrefix}.${thisMPASFileDate}.nc ${MeanBackgroundDirs[2]}/${BGFilePrefix}.${thisMPASFileDate}.nc
  else
    echo "Blending failed: No small scale file found" >> ./BLENDING_FAILED
    exit 9 
  endif
endif

if ( $nMembers > 1 ) then
  if ( ${ArgDAmethod} == "enkf" && ${blendingTarget} == "backgroundMean" ) then
    if ( -f ${MeanBackgroundDirs[1]}/${FCFilePrefix}.${thisMPASFileDate}.nc ) then
      cp ${MeanBackgroundDirs[1]}/${FCFilePrefix}.${thisMPASFileDate}.nc ${MeanBackgroundDirs[2]}/${BGFilePrefix}.${thisMPASFileDate}.nc
    else
      echo "Blending failed: No small scale file found" >> ./BLENDING_FAILED
      exit 9
    endif
  endif
  if ( "$blendingTarget" =~ background* ) then
    if ( ${ArgMemberIndex} == 0 ) then
      set small_scale_file = ${MeanBackgroundDirs[2]}/${BGFilePrefix}.${thisMPASFileDate}.nc
    else
      set small_scale_file = $CyclingDAInDirs[$ArgMemberIndex]/${BGFilePrefix}.${thisMPASFileDate}.nc
    endif  
  else if ( "$blendingTarget" =~ analysis* ) then
    if ( ${ArgMemberIndex} == 0 ) then
      set small_scale_file = ${MeanAnalysisDirs[2]}/${ANFilePrefix}.${thisMPASFileDate}.nc
    else    
      set small_scale_file = $CyclingDAOutDirs[$ArgMemberIndex]/${ANFilePrefix}.${thisMPASFileDate}.nc
    endif
  endif
else
  if ( "$blendingTarget" == "background" ) then
    set small_scale_file = ${CyclingDAInDir}/${BGFilePrefix}.${thisMPASFileDate}.nc
  else
    set small_scale_file = ${CyclingDAOutDir}/${ANFilePrefix}.${thisMPASFileDate}.nc
  endif
endif

if ( ! -f ${small_scale_file} ) then
  echo "Blending failed: small scale file ${small_scale_file} found" >> ./BLENDING_FAILED
  exit 9
endif

# Prepare files for blending 
[ -f ./large_scale_file.nc ] && rm ./large_scale_file.nc
ln -sf ${large_scale_file} ./large_scale_file.nc

[ -f ./small_scale_file.nc ] && rm ./small_scale_file.nc
ln -sf ${small_scale_file} ./small_scale_file.nc

# Prepare grid info
[ -f grid_info.txt ] && rm grid_info.txt
cp  ${blendingGridFile} ./grid_info.txt

# Gather blended variables
set blending_vars = ""
foreach var ( $blendingVariables )
   set blending_vars = "${blending_vars}'${var}',"
end
set blending_vars = `echo $blending_vars | sed 's/,$//'`

# namelist
[ -f input.nml ] && rm input.nml
cat > input.nml << EOF
&share
   grid_info_file = './grid_info.txt',
   large_scale_file = './large_scale_file.nc',
   small_scale_file = './small_scale_file.nc',
   output_blended_filename = './blended_file.nc',
   variables_to_blend = ${blending_vars}
   average_upscale_before_interp = .true.
   interp_method = 'bilinear'
   extrap_method = 'mpas_nearest'
   extrap_num_levels_creep = 64
   output_intermediate_files_up   = .false.
   output_intermediate_files_down = .false.
   output_upscaled_data_on_native_mesh = .false.
   output_blended_edge_normal_wind = .true.
   smooth_going_downscale = .false.
   smoother_dimensionless_coefficient = 0.1
/
&latlon_output
   output_latlon_grid = .false.
   is_regional = .false.
   nlat = 900
   nlon = 1300
   lat_ll = 27.
   lon_ll = -108.0
   dx_in_degrees = 0.04
   dy_in_degrees = 0.04
   extrap_method_latlon = 'none'
/
EOF

# Link executable 
ln -sf ${blendingBuildDir}/${blendingEXE} .

# Run executable for blending
${mpiCommand} ./${blendingEXE} >& blending.log

# Check whether blending worked as expected
if ( ! -e ./blended_file.nc ) then
  echo "Blending failed: no blended file generated" >> ./BLENDING_FAILED
  exit 9
else
  rm PET*
endif

# Handling blended variables
mv ${small_scale_file} ${small_scale_file}.nobld
cp ${small_scale_file}.nobld ${small_scale_file}

# Load NCO for the final output
ncks -A ./blended_file.nc ${small_scale_file}

echo "Blending succeed" >> ./BLENDING_SUCCESS

exit 0
