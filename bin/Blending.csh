#!/bin/csh -f

# (C) Copyright 2025 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# ArgWorkingDir: blending working directory
set ArgWorkingDir = "$1"

# ArgLargeScaleFile: large-scale state file, from global forecast/analysis
set ArgLargeScaleFile = "$2"

# ArgSmallScaleFile: small-scale state file, from mpas forecast or mpas-jedi analysis
set ArgSmallScaleFile = "$3"

# ArgBlendedFile: blended state file, saved as MPAS-JEDI background/analysis
set ArgBlendedFile = "$4"

# Env. setup
source config/environmentBlending.csh
source config/auto/build.csh
source config/auto/variational.csh
source config/tools.csh

# Working directory
echo "WorkDir = ${ArgWorkingDir}"
mkdir -p ${ArgWorkingDir}
cd ${ArgWorkingDir}

# Prepare files for blending 
[ -f ./large_scale_file.nc ] && rm ./large_scale_file.nc
ln -sf ${ArgLargeScaleFile} ./large_scale_file.nc
[ -f ./small_scale_file.nc ] && rm ./small_scale_file.nc
ln -sf ${ArgSmallScaleFile} ./small_scale_file.nc

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
   esmf_log = .true.
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

# Link exectuable 
ln -sf ${blendingBuildDir}/${blendingEXE} .

# Run exectuable for blending
${mpiCommand} ./${blendingEXE} >& blending.log

# Check whetehr blending worked as expected
if ( ! -e ./blended_file.nc ) then
  echo "Blending failed" >> ./BLENDING_FAILED
  exit 9
else
  rm PET*
endif

# Handling blended variables
ncks -A ./blended_file.nc ${ArgBlendedFile}

echo "Blending succeed" >> ./BLENDING_SUCCESS

exit 0
