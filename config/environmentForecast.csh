#!/bin/csh -f

if ( $?config_environmentForecast ) exit 0
setenv config_environmentForecast 1

source config/auto/build.csh # for forecastDirectory

if ("$forecastDirectory" == "bundle") then
  source config/environmentJEDI.csh
else
    if ( "$hpcSystem" == "cheyenne" ) then
      source /etc/profile.d/modules.csh
      module purge

      #gnu
      #module load gnu/9.1.0
      #setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'

      #intel
      module load intel/19.0.5

      module load mpt/2.22
      module load netcdf-mpi/4.7.3
      module load pnetcdf/1.12.1
      module load pio/2.4.4
      module load ncarenv/1.3
      module load ncarcompilers/0.5.0
      module load nco

      setenv mpiCommand mpiexec_mpt

    else if ("$hpcSystem" == "derecho") then
      
      source /etc/profile.d/z00_modules.csh
      
      module purge
      module load ncarenv/24.12
      module load craype/2.7.31
      module load intel/2024.2.1
      module load libfabric/1.15.2.0
      module load cray-mpich/8.1.29
      module load hdf5/1.12.3
      module load netcdf/4.9.2
      module load ncarcompilers/1.0.0
      module load parallel-netcdf/1.14.0
      module load nco/5.2.4

      if ( -e $PBS_NODEFILE ) then
         set ncpus = `wc -l < $PBS_NODEFILE`
         setenv mpiCommand "mpiexec -np ${ncpus}"
      else
         setenv mpiCommand mpiexec
      endif

    else if ( "$hpcSystem" == "aspire2a" ) then
      source /opt/cray/pe/modules/3.2.11.6/init/csh
      module purge
      module load craype-x86-milan
      module load PrgEnv-intel
      module load cray-netcdf/4.8.1.1 
      module load cray-parallel-netcdf/1.12.2.1
      if ( -e $PBS_NODEFILE ) then
         set ncpus = `wc -l < $PBS_NODEFILE`
         setenv mpiCommand "mpiexec -n ${ncpus}"
      endif

    else
      echo "unknown NCAR_HOST: $NCAR_HOST"
    endif

    setenv F_UFMTENDIAN 'big:101-200'
    setenv FI_CXI_RX_MATCH_MODE 'hybrid'
    limit stacksize unlimited
endif
