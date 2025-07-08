
Lara’s notes on building MPAS-A v8.3.0

SYSTEM: 
2020 MacBook Pro i-5 core 16 GB on Sequoia 15.5

LIBRARY VERSIONS:
Mpich-3.3.1
Zlib-1.2.11
Hdf5-1.13.0
pnetcdf-1.11.2
Netcdf-c-4.9.3
Netcdf-fortran-4.4.5
Pio-2.X

COMPILER VERSIONS
Homebrew gcc-15
Homebrew g++-15
Homebrew gfortran-15
MPICH mpicc
MPICH mpifort

Key Points:
- Use homebrew gnu compilers and deal with issues as they come, not clang
- Use the most up to date libraries for netcdf etc. 
- Micheal Duda’s script is a good baseline but has some issues


MPICH Build:
This is where the most issues were, and most of them were problems related to the apple clang compiler and Mac SDK issues.
1. I could not get the libraries to build with clang due to cross compatibility issues with gfortran. You need to install the gnu compilers from homebrew. However, this won’t work successfully unless you build it against the most up to date SDK.
    * If you don’t do this, you will get issues with the _bounds.h file and possibly other header files because these c++ header files are dependent on mac not the gnu compilers. So, you need to reinstall these completely and ensure you have the Xcode command line DEVELOPER tools.
    * First, update your Mac if needed, then uninstall existing gnu compilers from homebrew. 
    * To reinstall the Xcode command line tools:
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install
make clean
./configure
make
    * If you need to check for the existence of the file run
sudo find /Library /usr /System -name _bounds.h 2>/dev/null
        * This takes a while..
    * Now correctly set the paths to point to the SDK
export SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
export CPATH="$SDKROOT/usr/include"
export LIBRARY_PATH="$SDKROOT/usr/lib"
    * Now rebuild the gnu compilers FROM SOURCE as this will build them against the correct Mac SDK
brew uninstall gcc
brew install gcc --build-from-source
brew install gfortran --build-from-source
    * Now you need to force it to actually use these instead of clang. Just exporting the paths didn’t seem to work for me so I had to alias them in my bashrc
alias gcc=‘gcc-15’
alias g++=g++-15
alias gfortran=‘fortran-15’
    * After this I was able to build MPICH, but honestly it was a lot of trial and error.

ZLIB Build:
This was easy and gave me no issues, just follow Micheal Duda’s script.

HDF5 Build:
This was the second most problematic library to build, and it gave me a ton of random issues. I tried tons of versions but ultimately I solved them by just building the most up to date version. I also needed to add the --enable-fortran command to the ./compile command.
1. The following error was my main issue with most builds:
```H5HL.c:547:1: error: return type defaults to 'int' [-Wimplicit-int]
  547 | H5HL_insert(H5F_t *f, H5HL_t *heap, size_t buf_size, const void *buf, size_t *offset_out)
      | ^~~~~~~~~~~```
* Which is apparently a compiler version problem, as modern c++ compilers do not accept an implicit return of integers. This was not an issue with the most up to date version of HDF5 (1.13.0).
2. The other issues I had were with simple fortran and c test programs not building - this was due to the clashing clang and gnu compilers resolved in the MPICH build above.

PNETCDF Build:
The issue I got here was with making and it was a similar compiler version issue. Personally I think the fix I have here is kind of janky but hey… hopefully it doesn’t cause issues down the line…
```error: cannot use keyword 'false' as enumeration constant
enum {false=0, true=1};
      ^~~~~
note: 'false' is a keyword with '-std=c23' onwards```
* This is an issue with the latest C23 standard, which makes True and False a keyword instead of a classic boolean which doesn’t work with C++
* To fix this I just forced it to build with the C99 standard
`export CFLAGS="-std=gnu99"`

NETCDF-C and NETCDF-FORTRAN Build:
The errors I had here were with the link commands. I am genuinely not sure how I was able to do this after building parallel netcdf but whatever, maybe I forgot something I did along the way because I wasn’t taking notes as I went.. whoops
configure: error: Could not link to netcdf C library.
Please set LDFLAGS; for static builds set LIBS to the results of nc-config --libs.
To fix this I had to add them to all my linker and compiler flags
```which nc-config && nc-config --version ## locate netcdf
export CPPFLAGS="-I${LIBBASE}/include"
export LDFLAGS="-L${LIBBASE}/lib"
export LIBS="-lhdf5_hl -lhdf5 -lz -ldl"```
After this I was able to configure both fine and had minimal issues.

PIO Build:
I did this one like a classic build from source on GitHub, just using the most recent version at the time. Make sure you have cmake from homebrew. The main issue I had here was a cmake version issue, but I just overrode it:
```CMake Error at CMakeLists.txt:1 (cmake_minimum_required): Compatibility with CMake < 3.5 has been removed from CMake. Update the VERSION argument <min> value. Or, use the <min>...<max> syntax to tell CMake that the project requires at least <min> but has been updated to work with policies introduced by <max> or earlier. Or, add -DCMAKE_POLICY_VERSION_MINIMUM=3.5 to try configuring anyway.```
So I just added the flag and it build fine:
```cmake -DNetCDF_C_PATH=$NETCDF \
      -DNetCDF_Fortran_PATH=$NETCDF \
      -DPnetCDF_PATH=$PNETCDF \
      -DHDF5_PATH=$NETCDF \
      -DCMAKE_INSTALL_PREFIX=$LIBBASE \
      -DPIO_USE_MALLOC=ON \
      -DCMAKE_VERBOSE_MAKEFILE=1 \
      -DPIO_ENABLE_TIMING=OFF \
      ..
```

MPAS Build
I just cloned the latest version of MPAS from GitHub, ran 
`make gfortran CORE=atmosphere`
And it appears to have built fine. Below is my awkwardly edited version of Micheal Duda’s compile script, but I would err on the side of caution and do this line by line to make debugging easier:
```
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


make gfortran CORE=atmosphere```

