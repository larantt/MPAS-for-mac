## Notes on init_atmosphere_model module from MPAS

### 1. Creating static files ###
After you compile init_atmosphere_model, the first step is creating a static file for your mesh. 

I believe they also provide a default static file for the single resolution, standard meshes, but I wanted to be sure I was doing this correctly so I will be comparing mine to the provided one.
#### ISSUES ####
* In the user guide it states that you can use the WRF_GEOG files to create your static file. This appears to be incorrect, at least for MPAS V8.3.1!
    * Here I am testing for a 240 km standard global mesh.
    * When I used the WPS_GEOG static files I get the following error:
    ```
    CRITICAL ERROR: Error occured initalizing interpolation for /Users/laratobias-tarsh/Documents/atmos_models/data/static/WPS_GEOG/modis_landuse_20class_30s/ 
    ```
    * This makes sense, because if you use the provided [WPS_GEOG data](https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html), this land use data is actually called: `modis_landuse_20class_30s_with_lakes`.
    * Some [sporadic posts](https://forum.mmm.ucar.edu/threads/error-creating-static-file.5548/) on the user forums suggest this is an issue, but there seem to be far to few posts for this to be a consistent issue and there is no allusion to this in the [user guide](https://www2.mmm.ucar.edu/projects/mpas/mpas_atmosphere_users_guide_8.3.0.pdf)...
    * However, there **is** a different set of static files linked at https://www2.mmm.ucar.edu/projects/mpas/site/access_code/static.html which would suggest that these are the appropriate files to use.

#### NOTES ####
* `ncview` is no help with MPAS, as it can't handle the unstructured mesh, so you need a plotting script to check the static files
    * Supposedly there is an ncl script somewhere called plot_terrain.ncl but I don't see it anywhere
    * **TASK** - *work on a python script to quickly do this and flag potential weird values*
* The namelist settings in the user guide appear to work fine

### 2. Interpolating Real Data Initial Conditions ###
#### NOTES ####
* To process initial conditions, you need to generate intermediate input files using `ungrib.exe` from WPS, so you **MUST** build WPS unless you are using ERA5.
    * You actually don't need to build WRF to do this (whoops...), you can configure WPS with:
    ```
    ./configure --build-grib2-libs --nowrf
    ```
    * This will build WPS with the internal GRIB2 libraries (libPng, JasPer, zlib) provided when cloning the WPS source code.
* For ERA5, there is a python tool that can create intermediate files ([`era5_to_int`](https://github.com/NCAR/era5_to_int))

**An aside about WRF:**
* If you (like I foolishly did) decide to build WRF too, you almost definitely need to rebuild the libraries in a **separate location** instead of sharing libraries with MPAS
    * Following the MPAS tutorial suggests that the netcdf-c, netcdf-fortran and pnetcdf libraries need to be built **with** MPI compilers.
    * Following the WRF tutorial suggests that the netcdf-c, netcdf-fortran, HDF5 etc. need to be built **without** MPI compilers.
    * I did actually get WRF to compile successfully in dmpar mode using the libraries built with the MPI compilers, but I couldn't get 
    * **TASK** - *rebuild WRF and WPS with separately built dependencies (follow [this tutorial](https://forum.mmm.ucar.edu/threads/full-wrf-and-wps-installation-example-gnu.12385/))*

* It is not entirely clear to me what the minimum set of variables you need to run MPAS actually is. I am assuming it is either the same as WRF, or that it is the set of variables listed in the `era5_to_int` README.

#### EXPERIMENT 1 ####
The first experiment I am running is the provided [CFSR Test](https://www2.mmm.ucar.edu/projects/mpas/site/access_code/real_data.html) for 2010-10-23 but with a 240 km mesh. This does not check my instance of ungrib.exe, but I want to get through testing the code decently quickly. 
* Using the sample namelist and editing just to ensure the files were okay seemed to work succesfully, and the initial conditions it plotted seem very reasonable. (see `python_scripts/experiment_1_output`)
* NOTE this experiment does not include sea ice updates.
**Result**
* Everything ran pretty smoothly, with 4 processors on the i5 macbook pro, 5 days took about 22 minutes!

#### EXPERIMENT 2 ####
The second experiment I am running is the synoptics of the Edmund Fitzgerald (credit John and Kaleb) using ERA5 data on a 92-25km mesh. For this I also needed METIS to partition the grid for 4 MPI tasks.