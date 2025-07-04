#!/usr/bin/env bash

#
# Sources for all libraries used in this script can be found at
# http://www2.mmm.ucar.edu/people/duda/files/mpas/sources/ 
#

# Where to find sources for libraries
export LIBSRC=/Users/laratobias-tarsh/Documents/mpas_dependencies

# Where to install libraries
export LIBBASE=/Users/laratobias-tarsh/Documents/mpas_dependencies/installed

#export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)

# Compilers
export SERIAL_FC=gfortran
export SERIAL_F77=gfortran
export SERIAL_CC=gcc
export SERIAL_CXX=g++
export MPI_FC=mpifort
export MPI_F77=mpifort
export MPI_CC=mpicc
export MPI_CXX=mpic++


export CC=$SERIAL_CC
export CXX=$SERIAL_CXX
export F77=$SERIAL_F77
export FC=$SERIAL_FC
unset F90  # This seems to be set by default on NCAR's Cheyenne and is problematic
unset F90FLAGS
export CFLAGS="-g"
export FFLAGS="-g -fbacktrace -fallow-argument-mismatch"
export FCFLAGS="-g -fbacktrace -fallow-argument-mismatch"
export F77FLAGS="-g -fbacktrace -fallow-argument-mismatch"
#export LDFLAGS=-L/usr/local/Cellar/gcc/15.1.0/lib/gcc/15 -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib -L/usr/local/lib


########################################
# MPICH
########################################
tar xzvf ${LIBSRC}/mpich-3.3.1.tar.gz 
cd mpich-3.3.1
./configure --prefix=${LIBBASE}
make -j 4
#make check
make install
#make testing
export PATH=${LIBBASE}/bin:$PATH
export LD_LIBRARY_PATH=${LIBBASE}/lib:$LD_LIBRARY_PATH
cd ..
rm -rf mpich-3.3.1

########################################
# zlib
########################################
tar xzvf ${LIBSRC}/zlib-1.2.11.tar.gz
cd zlib-1.2.11
./configure --prefix=${LIBBASE} --static
make -j 4
make install
cd ..
rm -rf zlib-1.2.11

########################################
# HDF5
########################################
#tar xjvf ${LIBSRC}/hdf5-1.10.5.tar.bz2
tar xzvf ${LIBSRC}/hdf5-1.12.1.tar.gz
cd hdf5-1.12.1
export FC=$MPI_FC
export CC=$MPI_CC
export CXX=$MPI_CXX
./configure --prefix=${LIBBASE} --enable-parallel --enable-fortran --with-zlib=${LIBBASE} --enable-static
make -j 4
#make check
make install
cd ..
rm -rf hdf5-1.12.1

########################################
# Parallel-netCDF
########################################
tar xzvf ${LIBSRC}/pnetcdf-1.14.0.tar.gz
cd pnetcdf-1.14.0
export CFLAGS="-std=gnu99"
export CC=$SERIAL_CC
export CXX=$SERIAL_CXX
export F77=$SERIAL_F77
export FC=$SERIAL_FC
export MPICC=$MPI_CC
export MPICXX=$MPI_CXX
export MPIF77=$MPI_F77
export MPIF90=$MPI_FC
### Will also need gcc in path
./configure --prefix=${LIBBASE}
make -j 4
#make check
#make ptest
#make testing
make install
export PNETCDF=${LIBBASE}
cd ..
rm -rf pnetcdf-1.11.2

########################################
# netCDF (C library)
########################################
tar xzvf ${LIBSRC}/netcdf-c-4.9.3.tar.gz
cd netcdf-c-4.9.3
export CPPFLAGS="-I${LIBBASE}/include"
export LDFLAGS="-L${LIBBASE}/lib"
export LIBS="-lhdf5_hl -lhdf5 -lz -ldl"
export CC=$MPI_CC
./configure --prefix=${LIBBASE} --disable-dap --enable-netcdf4 --enable-pnetcdf --enable-cdf5 --enable-parallel-tests --disable-shared
make -j 4 
#make check
make install
export NETCDF=${LIBBASE}
cd ..
rm -rf netcdf-c-4.9.3

########################################
# netCDF (Fortran interface library)
########################################
tar xzvf ${LIBSRC}/netcdf-fortran-4.6.2.tar.gz
cd netcdf-fortran-4.6.2
export FC=$MPI_FC
export F77=$MPI_F77
export LIBS="-lnetcdf ${LIBS}"
export CPPFLAGS="-I${NETCDF}/include"
export LDFLAGS="-L${NETCDF}/lib"

export CPPFLAGS="$(${NETCDF}/bin/nc-config --cflags)"
export LDFLAGS="$(${NETCDF}/bin/nc-config --libs --static)"
export LIBS="$(${NETCDF}/bin/nc-config --libs --static)"


./configure --prefix=${LIBBASE} --enable-parallel-tests --disable-shared
make -j 4
#make check
make install
cd ..
rm -rf netcdf-fortran-4.4.5

########################################
# PIO
########################################
git clone https://github.com/NCAR/ParallelIO.git
cd ParallelIO
mkdir build
cd build
export PIOSRC=`pwd`
cd ..
mkdir pio
cd pio
export CC=$MPI_CC
export FC=$MPI_FC
#cmake -DNetCDF_C_PATH=$NETCDF -DNetCDF_Fortran_PATH=$NETCDF -DPnetCDF_PATH=$PNETCDF -DHDF5_PATH=$NETCDF -DCMAKE_INSTALL_PREFIX=$LIBBASE -DPIO_USE_MALLOC=ON -DCMAKE_VERBOSE_MAKEFILE=1 -DPIO_ENABLE_TIMING=OFF $PIOSRC
cmake -DNetCDF_C_PATH=$NETCDF \
      -DNetCDF_Fortran_PATH=$NETCDF \
      -DPnetCDF_PATH=$PNETCDF \
      -DHDF5_PATH=$NETCDF \
      -DCMAKE_INSTALL_PREFIX=$LIBBASE \
      -DPIO_USE_MALLOC=ON \
      -DCMAKE_VERBOSE_MAKEFILE=1 \
      -DPIO_ENABLE_TIMING=OFF \
      ..

#make
#make check
#make install
make -j$(nproc)
make install
cd ../..
rm -rf pio ParallelIO
export PIO=$LIBBASE

########################################
# Other environment vars needed by MPAS
########################################
export MPAS_EXTERNAL_LIBS="-L${LIBBASE}/lib -lhdf5_hl -lhdf5 -ldl -lz"
export MPAS_EXTERNAL_INCLUDES="-I${LIBBASE}/include"


## Different make commands - ALWAYS MAKE CLEAN FIRST
'''
init_atmosphere:
  - interpolates static fields to the mesh
  - generates a vertical grid
  - horizontally and vertically interpolate meteorological data to the 3d grid
  - initialise idealised cases
'''
make gfortran CORE=init_atmosphere USE_PIO2=true

'''
atmosphere:
  - the nonhydrostatic model itself
'''
make gfortran CORE=atmosphere USE_PIO2=true

# typical workflow (MPAS tutorial)
'''
make gfortran CORE=init_atmosphere USE_PIO2=true    # build the atmosphere_init core to set up meshes
make clean CORE=atmosphere                          # cleans any shared infrastructure used by both cores
make gfortran CORE=atmosphere USE_PIO2=true         # build the full atmosphere core to run the simulations

NOTES:
use the DEBUG=true flag when debugging seg faults (but clean first and after as it slows model down significantly)
to run in parallel use ifort as the compiler
'''
