files=`ls *.yaml`
for ifile in $files; do

  sed -i "s/brightness_temperature_jacobian_skin_temperature_at_surface/brightness_temperature_jacobian_surface_temperature/g" $ifile
  sed -i "s/brightness_temperature_jacobian_water_vapor_mixing_ratio_wrt_dry_air/brightness_temperature_jacobian_humidity_mixing_ratio/g" $ifile
  sed -i "s/height_above_mean_sea_level_at_surface/surface_altitude/g" $ifile
  echo $ifile
done
