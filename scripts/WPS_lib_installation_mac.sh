#!/usr/bin/env bash
# Ammended from the iolib_installation.sh script to include the extra libraries 
# needed for compiling WPS (WRF Preprocessing System) which is REQUIRED for processing
# real initial condition files!

# additional code was taken from this forum: https://forum.mmm.ucar.edu/threads/full-wrf-and-wps-installation-example-gnu.12385/
# Where to find sources for libraries
export LIBSRC=/Users/laratobias-tarsh/Documents/mpas_dependencies

# Where to install libraries
export LIBBASE=/Users/laratobias-tarsh/Documents/mpas_dependencies/installed


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

########################################
# JAPSER
########################################
tar xzvf ${LIBSRC}/jasper-4.2.5.tar.gz
cd jasper-4.2.5
mkdir ../jasper-build
cd ../jasper-build

cmake -H../jasper-4.2.5 -B. -DCMAKE_INSTALL_PREFIX=$LIBBASE
cmake --build .
# ctest --output-on-failure
cmake --build . --target install

export JASPERLIB="/$LIBBASE/lib"
export JASPERINC="/$LIBBASE/include"

cd ..
rm -rf jasper-X.Y.Z jasper-build

########################################
# LIBPNG
########################################
tar xzvf ${LIBSRC}/libpng-1.6.50.tar.gz
./configure --prefix=${LIBBASE}
make check
make install

# Note, ZLIB was installed with MPAS but have copied it here just incase
########################################
# zlib
########################################
# tar xzvf ${LIBSRC}/zlib-1.2.11.tar.gz
# cd zlib-1.2.11
# ./configure --prefix=${LIBBASE} --static
# make -j 4
# make install
# cd ..
# rm -rf zlib-1.2.11

export JASPERLIB="${JASPERLIB} -L/$LIBBASE/lib"
export JASPERINC="${JASPERINC} -I/$LIBBASE/include"


# NOTE - you MUST start a new terminal window here
########################################
# WRF
########################################
# Root directory where everything is installed
#export LIBBASE=/Users/laratobias-tarsh/Documents/mpas_dependencies/installed
# NetCDF root
#export NETCDF=$LIBBASE
# Set paths for dynamic linking and tool discovery
#export LD_LIBRARY_PATH=$NETCDF/lib:$LIBBASE/lib
#export PATH=$NETCDF/bin:$LIBBASE/bin:$PATH
# GRIB2 support (JasPer, PNG, zlib are in $LIBBASE/lib and $LIBBASE/include)
#export JASPERLIB=$LIBBASE/lib
#export JASPERINC=$LIBBASE/include

#export LD_FLAGS="-L${NETCDF}/lib -lnetcdff -lnetcdf \
#                 -L${PNETCDF}/lib -lpnetcdf \
#                 -L${HDF5}/lib -lhdf5_hl -lhdf5 \
#                 -lz -ldl -lm"


#export CPPFLAGS="-I$LIBBASE/include -I$LIBBASE/include"
#export LDFLAGS="-L$LIBBASE/lib -L$LIBBASE/lib -lnetcdf -lpnetcdf -lm -lbz2 -lxml2 -lcurl -lhdf5_hl -lhdf5 -lz -ldl"
#export LIBS="-L$LIBBASE/lib -L$LIBBASE/lib -lnetcdf -lpnetcdf -lm -lbz2 -lxml2 -lcurl -lhdf5_hl -lhdf5 -lz -ldl"

#export NETCDF_classic=1 # dont need compression here, we arent actually running sims

export LIBBASE=/Users/laratobias-tarsh/Documents/mpas_dependencies/installed

# Core library paths
export NETCDF=$LIBBASE
export PNETCDF=$LIBBASE
export HDF5=$LIBBASE

# Set paths for dynamic linking and tool discovery
export LD_LIBRARY_PATH=$NETCDF/lib:$LIBBASE/lib:$LD_LIBRARY_PATH
export PATH=$NETCDF/bin:$LIBBASE/bin:$PATH

# GRIB2 support (JasPer, PNG, zlib)
export JASPERLIB=$LIBBASE/lib
export JASPERINC=$LIBBASE/include

# Optional: explicit link flags for testing builds
export LD_FLAGS="-L${NETCDF}/lib -lnetcdff -lnetcdf \
                 -L${PNETCDF}/lib -lpnetcdf \
                 -L${HDF5}/lib -lhdf5_hl -lhdf5 \
                 -lz -ldl -lm"

# Ensure WRF uses classic NetCDF format
export NETCDF_classic=1

# Clone WRF with submodules
git clone --recurse-submodule https://github.com/wrf-model/WRF.git
cd WRF

./configure (choose options 35 and 1) # using 35 to build successfully with MPI only (gfortran not compatible with the MPAS builds)
./compile em_real -j 4 >& log.compile
# when it inveitably kills itself: grep -i error log.compile


#######################################
# WPS
#######################################
git clone https://github.com/wrf-model/WPS.git
cd WPS
#export WRF_DIR=path-to-WRF-top-level-directory/WRF
./configure (choose option 34 and 1)
./compile >& log.compile

# when it inveitably kills itself: grep -i error log.compile

################
# BONUS - METIS
################
git clone git@github.com:KarypisLab/GKlib.git
git clone https://github.com/KarypisLab/METIS.git

cd GKlib
make config CONFIG_FLAGS='-D BUILD_SHARED_LIBS=ON'
make
make install

cd ../METIS
sed -i .bak '/add_library(metis ${METIS_LIBRARY_TYPE} ${metis_sources})/ s/$/\ntarget_link_libraries(metis GKlib)/' libmetis/CMakeLists.txt
sed -i .bak '/^CONFIG_FLAGS \?= / s,$, -DCMAKE_BUILD_RPATH=${HOME}/.local/lib -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON,' Makefile
make config shared=1 cc=gcc prefix=/usr/local gklib_path=/usr/local
make
make install
export DYLD_LIBRARY_PATH="$HOME/local/lib:$DYLD_LIBRARY_PATH"
# gpmetis -minconn -contig -niter=200 x4.163842.graph.info 4