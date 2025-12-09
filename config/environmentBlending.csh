#!/bin/csh -f

source config/auto/build.csh

if ( "$hpcSystem" == "derecho" ) then
   echo "Set environments to Derecho"
   source /etc/profile.d/z00_modules.csh
   module purge
   module load ncarenv/23.09
   module load craype/2.7.23
   module load intel-oneapi/2023.2.1
   module load ncarcompilers/1.0.0
   module load cray-mpich/8.1.27
   module load hdf5-mpi/1.12.2
   module load netcdf-mpi/4.9.2
   module load mkl/2023.2.0
   module load esmf/8.6.0
   module load parallel-netcdf/1.12.3
   module load parallelio/2.6.2
   module load nco

  if ( -e $PBS_NODEFILE ) then
     set ncpus = `wc -l < $PBS_NODEFILE`
     setenv mpiCommand "mpiexec -np ${ncpus}"
  else
      setenv mpiCommand mpiexec
  endif

else if ( "$hpcSystem" == "aspire2a" ) then
  echo "Set environments to Aspire2a"
  source /opt/cray/pe/modules/3.2.11.6/init/csh

  # Basic modules
  module purge
  module load craype-x86-milan
  module load craype/2.7.15
  module load libfabric/1.11.0.4.125
  module load cray-pals/1.1.6
  module load gcc/11.2.0
  module load cray-mpich/8.1.15

  # spack-stack modules
  module use /data/projects/17001770/weather_department/dae/taosun/SPACK-STACK/spack-stack/envs/mpas-jedi/install/modulefiles/Core

  module load stack-gcc/11.2.0
  module load stack-cray-mpich/8.1.15
  module load python/3.11.7-by2ayqu

  module load netcdf-c/4.9.2
  module load netcdf-cxx4/4.3.1     
  module load netcdf-fortran/4.6.1
  module load parallel-netcdf/1.12.3
  module load esmf/8.6.1

  if ( -e $PBS_NODEFILE ) then
     set ncpus = `wc -l < $PBS_NODEFILE`
     setenv mpiCommand "mpiexec -np ${ncpus}"
  else
      setenv mpiCommand mpiexec
  endif

else
   echo "unknown host for blending. hpc system: $hpcSystem"
endif

module list
