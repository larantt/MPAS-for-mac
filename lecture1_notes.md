# LECTURE 1 NOTES #
Notes from NCAR lecture 1 (2021 WRF and MPAS tutorial on youtube)
## REAL DATA INITIAL CONDITIONS ##
Three key steps to this:
- Time invariant (static) fields (e.g. topography, soil categories, vegetation, land/sea masks)
- Generate vertical grid using terrain field, then interpolate atmospheric and land-surface initial conditions using analysis data
- Interpolate sea surface and sea ice fractions (useful because no fully prognostic 3D ocean)

### Producing initial conditions
First step is to download precomputed or prepared meshes from the MPAS home page through MPAS atmosphere meshes.

Each download gives a mesh itself and a mesh partition file (which firects the compute task partition file)
#### FILENAMES
- first part of filename indicates the refinement factor from coarses to finest part of mesh
- second part of filename indicates total number of cells in the mesh
- graph.info is the mesh connectivity tab that allows you to generate your own partitions for different numbers of processors

### init_atmosphere_model
- Handles all stages of processing real-data initial conditions
- Handles producing SSTs etc.
This program is run in different stages using different combinations of options:
#### init_atmosphere namelist
Key option is the config_init_case = x where:
2. = ideal baroclinic wave
4. = ideal squall line
5. = ideal supercell
6. = ideal mountain wave
7. = REAL DATA initialisation
8. = sfc update file creation (e.g. to update SSTs)
9. = lateral boundary conditions for LAMs

Once the config_init_case has been selected, set using logical flags in &preproc_stages

Generally every time init_atmosphere_model is run, you need to edit:
1. namelist.init_atmosphere
    - specify which sorts of "case" will be initialised
    - which sub-options are selected for that case 
2. streams.init_atmosphere
    - XML file
    - specifies which netcdf files will be read and written by the init_atmosphere_model program e.g. the location of the mesh

#### horizontally interpolating static fields:
- e.g. terrain elevation, dominant land cover category, dominant soil category, sub-grid scale terrain variance, climatological monthly vegetation fraction, climatological monthly surface albedo - can be used for ANY simulation with that mesh.
- usually borrowed from WRF (wrf/users/download/get_source.html) and need for running real sims

If everything is run correctly, the output will be the results of whatever you called it in the streams file, and will write out a log file with all the steps that the model took to interpolate the field. (imo look anyway to just check)

**FOR A REAL CASE**
1. set config_init_case to 7
2. set config_static_interp to true
3. set config_native_gwd_static to true (subgrid scale parameters used by gravity wave drag scheme in model, which don't change in time)
4. set all other preprocessing stages to false
5. go to &data_sources
6. set config_geog_data_path to the root directory for the WRF geographical data
7. probably best to use the defaults if using the WRF data
8. go to streams file
9. find input stream called "input" and "filename_template" which specifies the name of the mesh file that will be read by the program in processesing and set to the name of the mesh you downloaded
10. find "output" and set to same prefix `<prefix>.static.nc`

Now you can run the init_atmosphere program, result will be a static file which contains everything. Run this interactively, takes ~45 mins as it only runs on one processor.

#### Getting atmospheric initial conditions
* data needs to be in the ungrib component from WPS, so you need to build WPS (...?)
* once that has been done you need to run init_atmosphere again to get a new, interpolated set of initial conditions for MPAS simulation
#### namelist key settings
```
&nhyd_model
 config_init_case = 7
 config_start_time = 'yyyy-mm-dd-hh_MM_ss' # start time in UTC

&dimensions
 config_nvertlevels = xx # number of vertical layers used in model 3D inital conditions
 config_nsoillevels = 4  # has to be kept as this for the LSM used in MPAS
 config_nfglevels = xx   # (first guess levels) no. of levels in input file (as many as intermediate file)
 config_nfgsoillevels = 4 # has to default again

&data_sources
 config_met_prefix = 'MODEL_NAME:UTC_STRING' # gives the path to intermediate file in run directory
 config_use_spechumd = false

&vertical_grid
 config_ztop = 30000.0 # top layer of the model
 config_nsmterrain # number of smoothing passes for terrain
 config_smooth_surfaces # whether to smooth coordinate passes themselves
 config_dzmin = 0.3 # minimum delta zeta value
 ## NOTE - might want to more agressively smooth terrain at higher resolutions

&preproc_stages
 config_static_interp=false # already done in previous step
 config_native_gwd_static=false # already done in previous step
 config_vertical_grid_true # use terrain field provided and vertical grid settings to generate vertical grid
 config_met_interp = true # want to generate meteorological fields from the intermediate file
 config_input_sst = false
 config_frac_seaice = true
```
#### streams key settings
```
<immutable_stream name="input"
                   type="input"
                   filename_template=STATIC FILE PREVIOUSLY GENERATED
                   input_interval="initial_only" />

<immutable_stream name="output"
                   type="output"
                   filename_template=RESOLUTION_STRING.init.nc"
                   packages="initial_conds"
                   input_interval="initial_only" />
```

After running this you should get an init.nc file with:
1. everything from static file
2. 3-d vertical grid information
3. 3-d potential temperature
4. 3-d winds (u and w)
5. 3-d water vapor mixing ratio
6. 2-d soil moisture
7. 2-d soil temperature

#### PRODUCING SST AND SEA-ICE UPDATE FILES ####
Need to provide a mesh with a land-sea mask, which can be static file or initial conditions file, and need files that provide an SST and/or sea ice conditions. These are produced with WPS.

#### namelist key settings
```
&nhyd_model
 config_init_case = 8
 config_start_time = 'yyyy-mm-dd-hh_MM_ss' # start time in UTC (usually same as start of model)
 config_stop_time = 'yyyy-mm-dd-hh_MM_ss' # stop time in UTC (could be later)

&data_sources
 config_sfc_prefix='SST'
 config_fg_interval = 86400 # interval in seconds between files we are processing for updates

&preproc_stages
 config_static_interp=false # already done in previous step
 config_native_gwd_static=false # already done in previous step
 config_vertical_grid = false # use terrain field provided and vertical grid settings to generate vertical grid
 config_met_interp = false # want to generate meteorological fields from the intermediate file
 config_input_sst = true
 config_frac_seaice = true
 ```

#### streams key settings
```
<immutable_stream name="input"
                   type="input"
                   filename_template=STATIC FILE PREVIOUSLY GENERATED
                   input_interval="initial_only" />

<immutable_stream name="output"
                   type="output"
                   filename_template=RESOLUTION_STRING.sfc_update.nc"
                   packages="sfc_update"
                   input_interval="86400" # tells it to update, same as the namelist interval />
``` 
REMEMBER ALWAYS CHECK LOG FILE

### RUNNING BASIC SIMULATION ###
#### MESH PARTITION FILES ####
Almost always want to use multiple processors to run the model otherwise it takes too long.
* Generally need to use a program called METIS, which generates a partitioning which is continuous in space, and assigns to each processor.
* Sometimes you don't need to run METIS, just use a precomputed partition that comes with the downloaded mesh
* keep the mesh partition files in the working directory

#### atmosphere_model ####
* The same atmosphere_model executable can be used for either real-data or idealzied simulations

Given initial conditions all that is needed to run the model is:
1. Edit the namelist.atmosphere file to set the model timestep, mixing and damping parameters, physics options etc.
2. Edit the streams.atmosphere file to specify the name of the initial input confitions file and the frequecy of the model history files
3. Before running the model in parallel ensure that you have the proper mesh partition file in the working directory

#### namelist options to check ####
1. config_start_time - The starting time of the simulation, which should either match the time in the initial conditions or a model restart file
2. config_dt - The model timestep, in seconds, try starting with a timestep of between 5 and 6 times the minimum model grid spacing in km, also ensure that the mdoel output interval is evenly divided by the timestep 
3. config_len_disp - The length-scale used for explict horizontal mizing, set this to the minimum grid distance (in meters) in the mesh
4. also ensure that the names of input and output files are set correctly in the streams.atmosphere file

#### runtime monitoring ####
produces a logfile, only for MPI task 0, can run:
```
tail -f log.atmosphere.0000.out
```
to monitor model progress, gives information about how the schemes are being run in each timestep, get the summary of the min and max vertical velocities in each timestep in m/s, which can be used to sanity check the stability of the model, then get wall clock time for each integration step (can use for each simulation)

#### calculating simulation time ####
* total length of simulation using each step/time for each step

## IDEALISED INITIAL CONDITIONS ##
* Don't need any external datasets or preprocessing, model fields are prescribed by formulae
* just choose the initialization case and provide a mesh
* appendix A in MPAS users guide
* Good for checking any numerical scheme being developed

Some idealised cases require doubly-preiodic meshes:
* can download a prepared run directory for idealised cases
* after unpacking tar file, symlink the init_atmsophere_model and atmosphere_model executables into the resulting directory and follow the README instead!
* Can download these from the main MPAS page

