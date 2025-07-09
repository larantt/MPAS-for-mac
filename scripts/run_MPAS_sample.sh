#!/usr/bin/env bash
####################
# Script goes through how to quickly run an MPAS sim on MacOS based on the 2025 MPAS tutorial for real ICs
# https://www2.mmm.ucar.edu/projects/mpas/tutorial/Virtual2025/
# This isn't really intended to be run as a script, rather used as a guide
#
# PREREQS:
# 1. Have MPAS built so that it compiles
# 2. Have the mesh (and partition files if not creating with METIS) downloaded in a directory
# 3. Have the IC files (atmosphere and SST update) in the intermediate format from WPS ungrib
#
# NOTES:
# check the lbc entries don't fuck everything up...
# add preprocessing for variable resolution mesh
# add preprocessing for limited area runs if we are doing that?
####################

### GLOBALS ###
MPI_NPROCS=4
# filepaths
MESH_DIR=/Users/laratobias-tarsh/Documents/atmos_models/data/MPAS_meshes/92-25km_x4.163842 # path to where the mesh is downloaded
MPAS_DIR=/Users/laratobias-tarsh/Documents/atmos_models/MPAS_model
STATIC_DIR=/Users/laratobias-tarsh/Documents/atmos_models/data/static/mpas_static
ATMOS_DATA_DIR=/Users/laratobias-tarsh/Documents/atmos_models/data/CFSR_TEST
SST_DATA_DIR=/Users/laratobias-tarsh/Documents/atmos_models/data/SST_ERA5
PLOT_DIR=/Users/laratobias-tarsh/Documents/MPAS_notes/python_scripts

# naming variables
MESH_SIZE="240-48"       # size of mesh in km (can include the reduction for variable if desired)
MESH_TYPE="variable"     # just useful for naming (either uniform, variable or LAM)
MESH_EXT="x4.163842"      # "identifier code" for the downloaded mesh (needed for namelists etc)
RUN_EXT="ED_FITZ"      # name to give the specific run

# variables to edit if MESH_TYPE is variable
MESH_NAME="ed_fitz"     # name to give to the rotated mesh file
ROT_LAT=47.7           # specify where the central latitude of the refinement should go
ROT_LON=-87.5             # specify where the central longitude of the refinement should go
ROT_CCW=90              # rotate orientation of refinement with respect to the poles

# namelist variables
START_RUN=2010-10-23_00:00:00 # YYYY-MM-DD_hh:mm:ss
END_RUN=2010-10-28_00:00:00   # YYYY-MM-DD_hh:mm:ss
RUN_LEN=5_00:00:00            # D_hh:mm:ss (length of the run)

DT=1200.0                     # model timestep in seconds (between 5 and 6 times the minimum model grid size in km)
Z_TOP=30000.0                 # height of the top of atmospheric column
RAD_INT=01:00:00              # interval the radiation schemes are called at
HIST_OUT_INT=6:00:00          # how frequently to output history files (3d)
DIAG_OUT_INT=3:00:00          # how frequently to output diagnostics files (2d)
RESTART_INT=1_00:00:00        # how frequently to output restart files

UPDATE_OCEAN='true'          # are we updating the ocean data? 'false' or 'true'
FG_INTERVAL=86400             # interval between SST update files (int like 86400 or none)
LAM=false                     # are we doing a limited area simulation

MET_PREFIX='ERA5'             # model being used 
N_VERT_LEVS=55                # number of vertical levels in the model
N_SOIL_LEVS=4                 # number of soil levels being used in the model
N_FG_LEVS=38                  # number of first guess levels in the atmospheric dataset (forcing specific)
N_FG_SOIL_LEVS=4              # number of first guess soil levels in atmospheric dataset (forcing specific)

RUN_DIR=/Users/Documents/atmos_models/MPAS_runs/${MESH_SIZE}km_${MESH_TYPE}_${RUN_EXT}

## PROCESS ICs - can skip parts if the static variables and/or initial conditions have already been created ##
##
# Ensure all libraries are linked properly (script should do this for you)
source /Users/laratobias-tarsh/Documents/atmos_models/set_paths_MPAS.sh

# set $MESH_NAME to the same as $MESH_EXT if grid is uniform
if [[ "$MESH_TYPE" == "uniform" ]]; then
    echo "Using uniform grid - setting MESH_NAME to ${MESH_EXT}"
    MESH_NAME=$MESH_EXT
fi

# Compile the init_atmosphere core
cd $MPAS_DIR
make gfortran CORE=init_atmosphere

# Set up the run directory
mkdir $RUN_DIR
cd $RUN_DIR
ln -s ${MESH_DIR}/${MESH_EXT}.grid.nc .    # symlink the grid file for the mesh
ln -s ${MESH_DIR}/${MESH_EXT}.graph.info.part.${MPI_NPROCS} .  # symlink the mesh partition file

# if using a variable mesh, use grid_rotate to refine the mesh
if [[ "$MESH_TYPE" == "variable" ]]; then
    echo "rotating variable resolution grid"
    
    # if you are just doing everything manually and using this as a guide:
    # cp /Users/laratobias-tarsh/Documents/atmos_models/MPAS-Tools/mesh_tools/grid_rotate/namelist.input .
    
    # make the namelist for grid_rotate
    cat << EOF > namelist.input
&input
config_original_latitude_degrees = 0
config_original_longitude_degrees = 0

config_new_latitude_degrees = ${ROT_LAT}
config_new_longitude_degrees = ${ROT_LON}
config_birdseye_rotation_counter_clockwise_degrees = ${ROT_CCW}
/
EOF
    grid_rotate ${MESH_EXT}.grid.nc ${MESH_NAME}.grid.nc

fi

ln -s ${MPAS_DIR}/init_atmosphere_model .  # symlink the init_atmosphere executable

# NOTE - these are commented out if you just use the cat command to create a new file
# otherwise, copy then manually edit the namelist (which is what i would probably do lol)

#cp ${MPAS_DIR}/namelist.init_atmosphere .  # make a copy of the init_atmosphere namelist
#cp ${MPAS_DIR}/streams.init_atmosphere .   # make a copy of the init_atmosphere streams file

# PREPROC 1: Create the namelist for init_atmosphere STATIC files (adjust as needed if editing manually)
# NOTE - you only have to do this ONCE for each mesh!
cat << EOF > namelist.init_atmosphere
&nhyd_model
    config_init_case = 7
    config_start_time = '${START_RUN}'
    config_stop_time = '${START_RUN}'
    config_theta_adv_order = 3
    config_coef_3rd_order = 0.25
    config_interface_projection = 'linear_interpolation'
/
&dimensions
    config_nvertlevels = '${N_VERT_LEVS}'
    config_nsoillevels = '${N_SOIL_LEVS}'
    config_nfglevels = '${N_FG_LEVS}'
    config_nfgsoillevels = '${N_FG_SOIL_LEVS}'
    config_gocartlevels = 1
/
&data_sources
    config_geog_data_path = '${STATIC_DIR}'
    config_met_prefix = '${MET_PREFIX}'
    config_sfc_prefix = 'SST'
    config_fg_interval = 86400
    config_landuse_data = 'MODIFIED_IGBP_MODIS_NOAH'
    config_soilcat_data = 'STATSGO'
    config_topo_data = 'GMTED2010'
    config_vegfrac_data = 'MODIS'
    config_albedo_data = 'MODIS'
    config_maxsnowalbedo_data = 'MODIS'
    config_supersample_factor = 3
    config_lu_supersample_factor = 1
    config_30s_supersample_factor = 1
    config_use_spechumd = false
/
&vertical_grid
    config_ztop = '${Z_TOP}'
    config_nsmterrain = 1
    config_smooth_surfaces = true
    config_dzmin = 0.3
    config_nsm = 30
    config_tc_vertical_grid = true
    config_blend_bdy_terrain = false
/
&interpolation_control
    config_extrap_airtemp = 'lapse-rate'
/
&preproc_stages
    config_static_interp = true
    config_native_gwd_static = true
    config_native_gwd_gsl_static = false
    config_vertical_grid = false
    config_met_interp = false
    config_input_sst = false
    config_frac_seaice = false
/
&io
    config_pio_num_iotasks = 0
    config_pio_stride = 1
/
&decomposition
    config_block_decomp_file_prefix = '${MESH_EXT}.graph.info.part.'
/
EOF

# create the streams file for the STATIC files
cat << EOF > streams.init_atmosphere
<streams>
<immutable_stream name="input"
                  type="input"
                  filename_template="${MESH_NAME}.grid.nc"
                  input_interval="initial_only" />

<immutable_stream name="output"
                  type="output"
                  filename_template="${MESH_NAME}.static.nc"
                  packages="initial_conds"
                  output_interval="initial_only" />

<immutable_stream name="ugwp_oro_data"
                  type="output"
                  filename_template="${MESH_EXT}.ugwp_oro_data.nc"
                  packages="gwd_gsl_stage_out"
                  output_interval="initial_only" />

<immutable_stream name="surface"
                  type="output"
                  filename_template="${MESH_EXT}.sfc_update.nc"
                  filename_interval="none"
                  packages="sfc_update"
                  output_interval="86400" />

<immutable_stream name="lbc"
                  type="output"
                  filename_template="lbc.$Y-$M-$D_$h.$m.$s.nc"
                  filename_interval="output_interval"
                  packages="lbcs"
                  output_interval="3:00:00" />

</streams>
EOF

# now run init_atmosphere (NOTE - this is long, not sure if it can be done with MPI, I haven't tried yet)
./init_atmosphere
# mpirun -np 4 init_atmosphere

## Check on progress: 
## tail -f log.init_atmosphere.0000.out
## should look like this: Processing tile: /glade/campaign/mmm/wmr/mpas_tutorial/mpas_static/topo_gmted2010_30s/04801-06000.16801-18000
## check if the terrain file looks acceptable:
## python ${PLOT_DIR}/plot_terrain.py ${MESH_EXT}.static.nc

# PREPROC 2: Generate the real ICs for atmospheric vertical levels
# overwrite namelist.init_atmosphere to correspond with desired ICs
# main changes are to &preproc_stages, &nhyd_model and &data_sources
cat << EOF > namelist.init_atmosphere
&nhyd_model
    config_init_case = 7
    config_start_time = '${START_RUN}'
    config_stop_time = '${START_RUN}'
    config_theta_adv_order = 3
    config_coef_3rd_order = 0.25
    config_interface_projection = 'linear_interpolation'
/
&dimensions
    config_nvertlevels = '${N_VERT_LEVS}'
    config_nsoillevels = '${N_SOIL_LEVS}'
    config_nfglevels = '${N_FG_LEVS}'
    config_nfgsoillevels = '${N_FG_SOIL_LEVS}'
    config_gocartlevels = 1
/
&data_sources
    config_geog_data_path = '${ATMOS_DATA_DIR}'
    config_met_prefix = '${MET_PREFIX}'
    config_sfc_prefix = 'SST'
    config_fg_interval = 86400
    config_landuse_data = 'MODIFIED_IGBP_MODIS_NOAH'
    config_soilcat_data = 'STATSGO'
    config_topo_data = 'GMTED2010'
    config_vegfrac_data = 'MODIS'
    config_albedo_data = 'MODIS'
    config_maxsnowalbedo_data = 'MODIS'
    config_supersample_factor = 3
    config_lu_supersample_factor = 1
    config_30s_supersample_factor = 1
    config_use_spechumd = false
/
&vertical_grid
    config_ztop = '${Z_TOP}'
    config_nsmterrain = 1
    config_smooth_surfaces = true
    config_dzmin = 0.3
    config_nsm = 30
    config_tc_vertical_grid = true
    config_blend_bdy_terrain = false
/
&interpolation_control
    config_extrap_airtemp = 'lapse-rate'
/
&preproc_stages
    config_static_interp = false
    config_native_gwd_static = false
    config_native_gwd_gsl_static = false
    config_vertical_grid = true
    config_met_interp = true
    config_input_sst = false
    config_frac_seaice = true
/
&io
    config_pio_num_iotasks = 0
    config_pio_stride = 1
/
&decomposition
    config_block_decomp_file_prefix = '${MESH_EXT}.graph.info.part.'
/
EOF

# overwrite streams.init_atmosphere for desired ICs
# main changes are to input and output
cat << EOF > streams.init_atmosphere
<streams>
<immutable_stream name="input"
                  type="input"
                  filename_template="${MESH_NAME}.static.nc"
                  input_interval="initial_only" />

<immutable_stream name="output"
                  type="output"
                  filename_template="${MESH_NAME}.init.nc"
                  packages="initial_conds"
                  output_interval="initial_only" />

<immutable_stream name="ugwp_oro_data"
                  type="output"
                  filename_template="${MESH_EXT}.ugwp_oro_data.nc"
                  packages="gwd_gsl_stage_out"
                  output_interval="initial_only" />

<immutable_stream name="surface"
                  type="output"
                  filename_template="${MESH_EXT}.sfc_update.nc"
                  filename_interval="none"
                  packages="sfc_update"
                  output_interval="86400" />

<immutable_stream name="lbc"
                  type="output"
                  filename_template="lbc.$Y-$M-$D_$h.$m.$s.nc"
                  filename_interval="output_interval"
                  packages="lbcs"
                  output_interval="3:00:00" />

</streams>
EOF

# now run init_atmosphere (NOTE - this is long, not sure if it can be done with MPI, I haven't tried yet)
./init_atmosphere
# mpirun -np 4 init_atmosphere

## Check on progress: 
## tail -f log.init_atmosphere.0000.out
## check if the IC file looks acceptable:
## python ${PLOT_DIR}/plot_terrain.py ${MESH_EXT}.init.nc

# PREPROC 3 (OPTIONAL): process SST update files
if [[ "$UPDATE_OCEAN" == "true" ]]; then
    ln -s ${SST_DATA_DIR}/SST* .  # symlink all needed SST update files to the run directory
    # note, this may need to be edited to take a certain date range
    # e.g. for file in file{1..10}.txt; do ln -s "$file" /path/to/destination/"$file"; done

    # overwrite namelist.init_atmosphere to create SST files
    # main changes in &nhydmodel (NOTE config_init_case=8), &data_sources and &preproc_stages
    cat << EOF > namelist.init_atmosphere
&nhyd_model
    config_init_case = 8
    config_start_time = '${START_RUN}'
    config_stop_time = '${END_RUN}'
    config_theta_adv_order = 3
    config_coef_3rd_order = 0.25
    config_interface_projection = 'linear_interpolation'
/
&dimensions
    config_nvertlevels = '${N_VERT_LEVS}'
    config_nsoillevels = '${N_SOIL_LEVS}'
    config_nfglevels = '${N_FG_LEVS}'
    config_nfgsoillevels = '${N_FG_SOIL_LEVS}'
    config_gocartlevels = 1
/
&data_sources
    config_geog_data_path = '${SST_DATA_DIR}'
    config_met_prefix = '${MET_PREFIX}'
    config_sfc_prefix = 'SST'
    config_fg_interval = '${FG_INTERVAL}'
    config_landuse_data = 'MODIFIED_IGBP_MODIS_NOAH'
    config_soilcat_data = 'STATSGO'
    config_topo_data = 'GMTED2010'
    config_vegfrac_data = 'MODIS'
    config_albedo_data = 'MODIS'
    config_maxsnowalbedo_data = 'MODIS'
    config_supersample_factor = 3
    config_lu_supersample_factor = 1
    config_30s_supersample_factor = 1
    config_use_spechumd = false
/
&vertical_grid
    config_ztop = '${Z_TOP}'
    config_nsmterrain = 1
    config_smooth_surfaces = true
    config_dzmin = 0.3
    config_nsm = 30
    config_tc_vertical_grid = true
    config_blend_bdy_terrain = false
/
&interpolation_control
    config_extrap_airtemp = 'lapse-rate'
/
&preproc_stages
    config_static_interp = false
    config_native_gwd_static = false
    config_native_gwd_gsl_static = false
    config_vertical_grid = false
    config_met_interp = false
    config_input_sst = true
    config_frac_seaice = true
/
&io
    config_pio_num_iotasks = 0
    config_pio_stride = 1
/
&decomposition
    config_block_decomp_file_prefix = '${MESH_EXT}.graph.info.part.'
/
EOF

    # overwrite streams.init_atmosphere for desired ICs
    # main changes are to input and output
    cat << EOF > streams.init_atmosphere
<streams>
<immutable_stream name="input"
                type="input"
                filename_template="${MESH_NAME}.static.nc"
                input_interval="initial_only" />

<immutable_stream name="output"
                type="output"
                filename_template="${MESH_NAME}.init.nc"
                packages="initial_conds"
                output_interval="initial_only" />

<immutable_stream name="ugwp_oro_data"
                type="output"
                filename_template="${MESH_NAME}.ugwp_oro_data.nc"
                packages="gwd_gsl_stage_out"
                output_interval="initial_only" />

<immutable_stream name="surface"
                type="output"
                filename_template="${MESH_NAME}.sfc_update.nc"
                filename_interval="none"
                packages="sfc_update"
                output_interval="${FG_INTERVAL}" />

<immutable_stream name="lbc"
                type="output"
                filename_template="lbc.$Y-$M-$D_$h.$m.$s.nc"
                filename_interval="output_interval"
                packages="lbcs"
                output_interval="3:00:00" />

</streams>
EOF
    ./init_atmosphere
    # mpirun -np 4 init_atmosphere

    ## Check on progress:
    ## check if the data contains the correct times:
    ## ncdump -v xtime ${MESH_EXT}.sfc_update.nc
    ## check if the SST file looks acceptable:
    ## python ${PLOT_DIR}/plot_delta_sst.py ${MESH_EXT}.sfc_update.nc
fi

## INTEGRATE THE MODEL - this is the fun running part! This is set up for my Mac so I only have 4 processors to work with ##
##
# clean the init_atmosphere core and make the atmosphere core
cd $MPAS_DIR
make clean CORE=init_atmosphere
make gfortran CORE=atmosphere

cd $RUN_DIR
ln -s ${MPAS_DIR}/atmosphere_model .      # symlink the atmosphere executable
cp ${MPAS_DIR}/stream_list.atmosphere.* . # copy the stream lists for the atmosphere core (DIFFERENT to streams)
ln -s ${MPAS_DIR}/src/core_atmosphere/physics/physics_wrf/files/* . # symlink to files needed for model physics

# NOTE - these are commented out if you just use the cat command to create a new file
# otherwise, copy then manually edit the namelist (which is what i would probably do lol)

#cp ${MPAS_DIR}/namelist.atmosphere .  # make a copy of the atmosphere namelist
#cp ${MPAS_DIR}/streams.atmosphere .   # make a copy of the atmosphere streams file

# Write the namelist.atmosphere file
cat << EOF > namelist.atmosphere
&nhyd_model
    config_time_integration_order = 2
    config_dt = ${DT}
    config_start_time = '${START_RUN}'
    config_run_duration = '${RUN_LEN}'
    config_split_dynamics_transport = true
    config_number_of_sub_steps = 2
    config_dynamics_split_steps = 3
    config_horiz_mixing = '2d_smagorinsky'
    config_visc4_2dsmag = 0.05
    config_scalar_advection = true
    config_monotonic = true
    config_coef_3rd_order = 0.25
    config_epssm = 0.1
    config_smdiv = 0.1
/
&damping
    config_zd = 22000.0
    config_xnutr = 0.2
/
&limited_area
    config_apply_lbcs = ${LAM}
/
&io
    config_pio_num_iotasks = 0
    config_pio_stride = 1
/
&decomposition
    config_block_decomp_file_prefix = '${MESH_EXT}.graph.info.part.'
/
&restart
    config_do_restart = false
/
&printout
    config_print_global_minmax_vel = true
    config_print_detailed_minmax_vel = false
/
&IAU
    config_IAU_option = 'off'
    config_IAU_window_length_s = 21600.
/
&physics
    config_sst_update = false
    config_sstdiurn_update = false
    config_deepsoiltemp_update = false
    config_radtlw_interval = '${RAD_INT}'
    config_radtsw_interval = '${RAD_INT}'
    config_bucket_update = 'none'
    config_physics_suite = 'mesoscale_reference'
/
&soundings
    config_sounding_interval = 'none'
/
&physics_lsm_noahmp
    config_noahmp_iopt_dveg = 4
    config_noahmp_iopt_crs = 1
    config_noahmp_iopt_btr = 1
    config_noahmp_iopt_runsrf = 3
    config_noahmp_iopt_runsub = 3
    config_noahmp_iopt_sfc = 1
    config_noahmp_iopt_frz = 1
    config_noahmp_iopt_inf = 1
    config_noahmp_iopt_rad = 3
    config_noahmp_iopt_alb = 1
    config_noahmp_iopt_snf = 1
    config_noahmp_iopt_tksno = 1
    config_noahmp_iopt_tbot = 2
    config_noahmp_iopt_stc = 1
    config_noahmp_iopt_gla = 1
    config_noahmp_iopt_rsf = 4
    config_noahmp_iopt_soil = 1
    config_noahmp_iopt_pedo = 1
    config_noahmp_iopt_crop = 0
    config_noahmp_iopt_irr = 0
    config_noahmp_iopt_irrm = 0
    config_noahmp_iopt_infdv = 1
    config_noahmp_iopt_tdrn = 0
/
EOF

# Write the streams.atmosphere file
cat << EOF > streams.atmosphere
<streams>
<immutable_stream name="input"
                  type="input"
                  filename_template="${MESH_NAME}.init.nc"
                  input_interval="initial_only" />

<immutable_stream name="restart"
                  type="input;output"
                  filename_template="restart.$Y-$M-$D_$h.$m.$s.nc"
                  input_interval="initial_only"
                  output_interval="${RESTART_INT}" />

<stream name="output"
        type="output"
        filename_template="history.$Y-$M-$D_$h.$m.$s.nc"
        output_interval="${HIST_OUT_INT}" >

	<file name="stream_list.atmosphere.output"/>
</stream>

<stream name="diagnostics"
        type="output"
        filename_template="diag.$Y-$M-$D_$h.$m.$s.nc"
        output_interval="${DIAG_OUT_INT}" >

	<file name="stream_list.atmosphere.diagnostics"/>
</stream>

<stream name="surface"
        type="input"
        filename_template="${MESH_NAME}.sfc_update.nc"
        filename_interval="none"
        input_interval="${FG_INTERVAL}" >

	<file name="stream_list.atmosphere.surface"/>
</stream>

<immutable_stream name="iau"
                  type="input"
                  filename_template="${MESH_EXT}.AmB.$Y-$M-$D_$h.$m.$s.nc"
                  filename_interval="none"
                  packages="iau"
                  input_interval="initial_only" />

<immutable_stream name="lbc_in"
                  type="input"
                  filename_template="lbc.$Y-$M-$D_$h.$m.$s.nc"
                  filename_interval="input_interval"
                  packages="limited_area"
                  input_interval="3:00:00" />

<immutable_stream name="ugwp_oro_data_in"
                  type="input"
                  filename_template="${MESH_EXT}.ugwp_oro_data.nc"
                  packages="ugwp_orog_stream"
                  input_interval="initial_only" />

<immutable_stream name="ugwp_ngw_in"
                  type="input"
                  filename_template="ugwp_limb_tau.nc"
                  packages="ugwp_ngw_stream"
                  input_interval="initial_only" />

<immutable_stream name="da_state"
                  type="input;output"
                  filename_template="mpasout.$Y-$M-$D_$h.$m.$s.nc"
                  packages="jedi_da"
                  input_interval="initial_only"
                  output_interval="0_06:00:00" />

<stream name="diag_ugwp"
        type="output"
        filename_template="diag_ugwp.$Y-$M-$D_$h.$m.$s.nc"
        packages="ugwp_diags_stream"
        output_interval="6:00:00" >

	<file name="stream_list.atmosphere.diag_ugwp"/>
</stream>

</streams>
EOF

# now symlink the mesh partition file for the correct number of processors
ln -s ${MESH_DIR}/${MESH_EXT}.graph.info.part.${MPI_NPROCS} .

# run the atmosphere model!
mpirun -np ${MPI_NPROCS} atmosphere_model 

## Check on progress: 
## tail -f log.atmosphere.0000.out

## Output:
# diag.*.nc — These files contain mostly 2-d diagnostic fields that were listed in the stream_list.atmosphere.diagnostics file.
# history.*.nc — These files contain mostly 3-d prognostic and diagnostic fields from the model.
# restart.*.nc — These are model restart files that are essentially checkpoints of the model state; a simulation can be re-started from any of these checkpoint/restart files.
# these can be checked quickly in ncview with the convert_mpas utility