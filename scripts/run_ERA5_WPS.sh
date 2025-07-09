#!/usr/bin/env bash
####################
# Script goes through how to run WPS ungrib for ERA5 in order to demonstrate
# how to preprocess the data.
#
# For this script the ERA5 data is assumed to be downloaded from the CDS API
# which is demonstrated in the get_ERA5_cds.py script.
#
# NOTE: this assumes that ungrib.exe has been compiled successfully
####################

## GLOBALS ##
WPS_DIR=/Users/laratobias-tarsh/Documents/atmos_models/WPS  # where WPS is
DATA_IN_DIR=/Users/laratobias-tarsh/Documents/atmos_models/data/ERA5/1975-11-08_1975-11-11 # where the raw ERA5 data is
DATA_OUT_DIR=$DATA_IN_DIR/met_data # where to store ungribbed data

START_DATE='1975-11-08_00:00:00'      # start date of simulation
END_DATE='1975-11-11_00:00:00'        # end date of simulation
INTERVAL=21600                        # interval between files to ungrib (only SST) in seconds (21600 for 6 hrs)
PREFIX='ERA5'                         # prefix of the output file names

# set the path to the libraries
source /Users/laratobias-tarsh/Documents/atmos_models/set_paths_MPAS.sh

mkdir -p $DATA_OUT_DIR

cd $WPS_DIR
# ./configure --nowrf --build-grib2-libs    #(only do this if you haven't already built this)

# clean up the WPS directory
echo "Checking for existing GRIBFILE* files or Vtable..."

# check if the files exist
GRIBFILES_EXIST=$(ls GRIBFILE.* 2>/dev/null)
VTABLE_EXIST=$(test -e Vtable && echo "yes")

if [[ -n "$GRIBFILES_EXIST" || -n "$VTABLE_EXIST" ]]; then
    echo "WARNING: found existing GRIBFILE.* and Vtable:"

    # Remove GRIBFILEs
    if [[ -n "$GRIBFILES_EXIST" ]]; then
        ls -lh GRIBFILE.*
        rm -f GRIBFILE.*
        echo "Removed existing GRIBFILE.* files."
    fi

    # Remove Vtable
    if [[ -n "$VTABLE_EXIST" ]]; then
        ls -lh Vtable
        rm -f Vtable
        echo "Removed existing Vtable."
    fi
else
    echo "No GRIBFILE.* files or Vtable found."
fi

echo "Generating namelist.wps"
# Create the namelist.wps file
cat << EOF > namelist.wps
&share
 wrf_core = 'ARW',
 max_dom = 1,
 start_date = '${START_DATE}',
 end_date   = '${START_DATE}',
 interval_seconds = ${INTERVAL}
/

&geogrid
 parent_id         =   1,   1,
 parent_grid_ratio =   1,   3,
 i_parent_start    =   1,  53,
 j_parent_start    =   1,  25,
 e_we              =  150, 220,
 e_sn              =  130, 214,
 geog_data_res = 'default','default',
 dx = 15000,
 dy = 15000,
 map_proj = 'lambert',
 ref_lat   =  33.00,
 ref_lon   = -79.00,
 truelat1  =  30.0,
 truelat2  =  60.0,
 stand_lon = -79.0,
 geog_data_path = '/glade/work/wrfhelp/WPS_GEOG/'
/

&ungrib
 out_format = 'WPS',
 prefix = '${PREFIX}',
/

&metgrid
 fg_name = 'FILE'
/
EOF

echo "Linking input data and Vtable"

ln -s ungrib/Variable_Tables/Vtable.ECMWF Vtable
./link_grib.csh $DATA_IN_DIR/ERA5 .

echo "Running ungrib for initial conditions"
./ungrib.exe

echo "moving output to ${DATA_OUT_DIR}"
mv ERA5* $DATA_OUT_DIR

echo "Running ungrib for SSTs"
rm -f GRIBFILE.*
./link_grib.csh $DATA_IN_DIR/SST .

echo "Generating namelist.wps"
# Create the namelist.wps file
cat << EOF > namelist.wps
&share
 wrf_core = 'ARW',
 max_dom = 1,
 start_date = '${START_DATE}',
 end_date   = '${END_DATE}',
 interval_seconds = ${INTERVAL}
/

&geogrid
 parent_id         =   1,   1,
 parent_grid_ratio =   1,   3,
 i_parent_start    =   1,  53,
 j_parent_start    =   1,  25,
 e_we              =  150, 220,
 e_sn              =  130, 214,
 geog_data_res = 'default','default',
 dx = 15000,
 dy = 15000,
 map_proj = 'lambert',
 ref_lat   =  33.00,
 ref_lon   = -79.00,
 truelat1  =  30.0,
 truelat2  =  60.0,
 stand_lon = -79.0,
 geog_data_path = '/glade/work/wrfhelp/WPS_GEOG/'
/

&ungrib
 out_format = 'WPS',
 prefix = 'SST',
/

&metgrid
 fg_name = 'FILE'
/
EOF

./ungrib.exe

echo "moving output to ${DATA_OUT_DIR}"
mv SST* $DATA_OUT_DIR

