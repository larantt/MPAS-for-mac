#!/usr/bin/env bash

# script sets all the paths I used to build MPAS and WPS
#!/bin/bash

# Path to library sources and install location
export LIBSRC=/Users/laratobias-tarsh/Documents/mpas_dependencies
export LIBBASE=/Users/laratobias-tarsh/Documents/mpas_dependencies/installed

# Serial compilers
export SERIAL_CC=gcc
export SERIAL_CXX=g++
export SERIAL_FC=gfortran
export SERIAL_F77=gfortran

# MPI compilers (from your MPICH build)
export MPI_CC=mpicc
export MPI_CXX=mpic++
export MPI_FC=mpifort
export MPI_F77=mpifort

# Use MPI compilers
export CC=$MPI_CC
export CXX=$MPI_CXX
export FC=$MPI_FC
export F77=$MPI_F77
unset F90 F90FLAGS

# Compilation flags
export CFLAGS="-g"
export FFLAGS="-g -fbacktrace -fallow-argument-mismatch"
export FCFLAGS="$FFLAGS"
export F77FLAGS="$FFLAGS"

# Path to installed libraries
export NETCDF=$LIBBASE
export HDF5=$LIBBASE
export PNETCDF=$LIBBASE
export PIO=$LIBBASE

# Flags for building and linking
export CPPFLAGS="-I$LIBBASE/include -I$LIBBASE/include"
export LDFLAGS="-L$LIBBASE/lib -L$LIBBASE/lib -lnetcdf -lpnetcdf -lm -lbz2 -lxml2 -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lnetcdff"
export LIBS="-L$LIBBASE/lib -L$LIBBASE/lib -lnetcdf -lpnetcdf -lm -lbz2 -lxml2 -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lnetcdff"

# Ensure tools like nc-config are found
export PATH="$LIBBASE/bin:$PATH"
export LD_LIBRARY_PATH="$LIBBASE/lib:$LD_LIBRARY_PATH"

# For MPAS build system
export MPAS_EXTERNAL_INCLUDES="-I${LIBBASE}/include"
export MPAS_EXTERNAL_LIBS="-L${LIBBASE}/lib -lhdf5_hl -lhdf5 -ldl -lz"

# Print checks
echo "CHECKING PATHS..."
# Expected base path
EXPECTED_BASE="/Users/laratobias-tarsh/Documents/mpas_dependencies/installed"

# Color helper
ok() { echo -e "\033[0;32m[OK]\033[0m $1"; }
warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }
fail() { echo -e "\033[0;31m[FAIL]\033[0m $1"; }

# Check function
check_var() {
    local name="$1"
    local expected="$2"
    local actual="${!name}"

    if [[ "$actual" == "$expected" ]]; then
        ok "$name is correctly set to $expected"
    else
        fail "$name is '$actual', expected '$expected'"
    fi
}

# Check environment variables
check_var NETCDF "$EXPECTED_BASE"
check_var PNETCDF "$EXPECTED_BASE"
check_var HDF5 "$EXPECTED_BASE"
check_var PIO "$EXPECTED_BASE"
check_var LIBBASE "$EXPECTED_BASE"

# Check compilers
check_var CC "mpicc"
check_var FC "mpifort"
check_var F77 "mpifort"
check_var CXX "mpic++"

# Check path contains installed bin
if [[ ":$PATH:" == *":$EXPECTED_BASE/bin:"* ]]; then
    ok "PATH includes $EXPECTED_BASE/bin"
else
    fail "PATH does not include $EXPECTED_BASE/bin"
fi

# Check include and library paths
if [[ "$CPPFLAGS" == *"-I$EXPECTED_BASE/include"* ]]; then
    ok "CPPFLAGS includes -I$EXPECTED_BASE/include"
else
    warn "CPPFLAGS missing -I$EXPECTED_BASE/include"
fi

if [[ "$LDFLAGS" == *"-L$EXPECTED_BASE/lib"* ]]; then
    ok "LDFLAGS includes -L$EXPECTED_BASE/lib"
else
    warn "LDFLAGS missing -L$EXPECTED_BASE/lib"
fi

# Check nc-config and netcdf version
if command -v nc-config &> /dev/null; then
    NETCDF_VERSION=$(nc-config --version)
    ok "nc-config found, NetCDF version: $NETCDF_VERSION"
else
    fail "nc-config not found in PATH"
fi

# Optional: Test linking
echo "int main() { return 0; }" > linktest.c
mpicc linktest.c -o linktest $(nc-config --libs) &> /dev/null
if [[ $? -eq 0 ]]; then
    ok "NetCDF link test succeeded"
else
    fail "NetCDF link test failed"
fi
rm -f linktest.c linktest