#!/bin/csh -f

if ( $?config_environmentJEDI ) exit 0

set spack_version="1.6.0"
echo "Loading Spack-Stack $spack_version"
setenv config_environmentJEDI 1

source config/auto/build.csh

if ( "$hpcSystem" == "derecho" ) then
  source /etc/profile.d/z00_modules.csh
  module purge
  setenv LMOD_TMOD_FIND_FIRST yes
  set spack_version = "1.6.0"
  echo "Loading Spack-Stack $spack_version"
  if ( "$bundleCompilerUsed" =~  *"intel"* ) then
     module use /lustre/desc1/scratch/epicufsrt/contrib/modulefiles_extra
     module use /lustre/desc1/scratch/epicufsrt/contrib/modulefiles
     module load ecflow/5.8.4
     module load mysql/8.0.33
     module use /glade/work/epicufsrt/contrib/spack-stack/derecho/spack-stack-${spack_version}/envs/unified-env/install/modulefiles/Core
     module load stack-intel/2021.10.0
     module load stack-cray-mpich/8.1.25
     module load stack-python/3.10.8
     module load jedi-mpas-env
  else if ( "$bundleCompilerUsed" =~  *"gnu"* ) then
     module load ncarenv/23.09
     module use /glade/work/epicufsrt/contrib/spack-stack/derecho/modulefiles
     module load ecflow/5.8.4
     module load mysql/8.0.33
     module use /glade/work/epicufsrt/contrib/spack-stack/derecho/spack-stack-${spack_version}/envs/unified-env/install/modulefiles/Core
     module load stack-gcc/12.2.0
     module load stack-cray-mpich/8.1.25
     module load stack-python/3.10.8
     module load jedi-mpas-env soca-env
  endif

  echo setenv LD_LIBRARY_PATH ${mpasBundle}/lib:$LD_LIBRARY_PATH
  setenv LD_LIBRARY_PATH ${mpasBundle}/lib:$LD_LIBRARY_PATH
  setenv mpiCommand mpiexec

else if ( "$hpcSystem" == "cheyenne" ) then
  source /etc/profile.d/modules.csh
  module purge
  setenv LMOD_TMOD_FIND_FIRST yes
  module unuse /glade/u/apps/ch/modulefiles/default/compilers
  setenv MODULEPATH_ROOT /glade/work/jedipara/cheyenne/spack-stack/modulefiles
  module use /glade/work/jedipara/cheyenne/spack-stack/modulefiles/compilers
  module use /glade/work/jedipara/cheyenne/spack-stack/modulefiles/misc
  module use /glade/work/epicufsrt/contrib/spack-stack/spack-stack-1.3.1/envs/unified-env/install/modulefiles/Core

  if ( "$bundleCompilerUsed" =~  *"gnu"* ) then
    module load stack-gcc/10.1.0
    module load stack-openmpi/4.1.1
  else if ( "$bundleCompilerUsed" =~  *"intel"* ) then
    module load stack-intel/19.1.1.217
    module load stack-intel-mpi/2019.7.217
  endif
  module load jedi-mpas-env/unified-dev
  setenv mpiCommand mpiexec_mpt

else if ( "$hpcSystem" == "aspire2a" ) then
  echo "Set environments to aspire2a"
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
  module use /data/projects/17001770/weather_department/cmd/ncar/taosun/SPACK-STACK/spack-stack/envs/bundleCray/install/modulefiles/Core  

  module load stack-gcc/11.2.0
  module load stack-cray-mpich/8.1.15
  module load stack-python/3.11.7

  module load boost/1.84.0-5wqzejm \
             c-blosc/1.21.5-bgjxxo4 \
             ca-certificates-mozilla/2023-05-30-wzugmzm \
             cmake/3.27.9-gmqmixo \
             curl/8.7.1-uikqdrq \
             ecbuild/3.7.2 \
             eigen/3.4.0-bg7vnxs \
             gettext/0.22.5-2urkoke \
             glibc/2.28-hfg4z4r \
             gsl-lite/0.37.0 \
             help2man/1.49.3-7glkygl \
             jedi-cmake/1.4.0 \
             libmd/1.0.4-rhjyyzw \
             libxcrypt/4.4.35-uuhhm4f \
             nghttp2/1.57.0-dgwd3vb \
             pigz/2.8-wolfrqk \
             py-pip/23.1.2-devvkpo \
             py-pycodestyle/2.11.0 \
             py-setuptools/63.4.3-igxg7ik \
             py-wheel/0.41.2-u4h2yf5 \
             python/3.11.7-ksdmh72 \
             python-venv/1.0-slfupkl \
             snappy/1.1.10-3pd7fj2 \
             sqlite/3.43.2-mygtywj \
             tar/1.34-pagn5fx \
             udunits/2.2.28 \
             util-linux-uuid/2.38.1-kwh6ug3 \
             zlib-ng/2.1.6-pp5dv7m \
             zstd/1.5.2-mi2ki6h
  
  # MPI-related
  module load eckit/1.25.2 \
             ecmwf-atlas/0.36.0 \
             fckit/0.11.0-cceznly \
             fftw/3.3.10-r2kb5ze \
             gptl/8.1.1 \
             hdf5/1.14.3-kh4pj34 \
             nccmp/1.9.0.1 \
             netcdf-c/4.9.2-gllauhr \
             netcdf-cxx4/4.3.1 \
             netcdf-fortran/4.6.1-gd7hnwz \
             parallel-netcdf/1.12.3-xdnltho \
             parallelio/2.6.2-nrbojhw

  echo "MPAS_BUNDLE: ${mpasBundle}/lib"
  setenv LD_LIBRARY_PATH ${mpasBundle}/lib:$LD_LIBRARY_PATH

  if ( -e $PBS_NODEFILE ) then
     set ncpus = `wc -l < $PBS_NODEFILE`
     setenv mpiCommand "mpiexec -n ${ncpus}"
  endif

else
  echo "unknown HPC System:" $hpcSystem
endif

limit stacksize unlimited
setenv OOPS_TRACE 0
setenv OOPS_DEBUG 0
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'
setenv OMP_NUM_THREADS 1
setenv FI_CXI_RX_MATCH_MODE 'hybrid'

module list
