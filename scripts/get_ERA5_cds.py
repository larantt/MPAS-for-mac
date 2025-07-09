#!/usr/bin/env python
"""
Author: Lara Tobias-Tarsh (laratt@umich.edu)
Created: Tuesday July 8th 2025

This script uses the CDS API to download the necessary ERA5 data to initialise an MPAS (or WRF) simulation.
Data is downloaded in GRIB2 format for use in the WPS ungrib program.

To run, just edit the globals for the dates you need then run:
```
python get_ERA5_cds.py
```
After this step, the data needs to be passed to ungrib.exe before being used to force the model

NOTE: for use in ungrib, you need to ensure all files begin with the model prefix (e.g. ERA5)

TO DO:
- [ ] allow terminal input so that downloading data and calling ungrib can be automated with a single bash script
"""

#############
## IMPORTS ##
#############
import cdsapi
import os
from pathlib import Path

#############
## GLOBALS ##
#############
# terminal formatting (leave alone)
BOLD = '\033[1m'
END = '\033[0m'

# set paths
OUTPATH = "/Users/laratobias-tarsh/Documents/atmos_models/data/ERA5"  # where to write output data

# set run specific variables
START_DATE='1975-11-08'  # initialization date for simulation (YYYY-MM-DD)
START_HOUR='00'          # hour to initialize simulation (HH), should probably default to 0z (00)

UPDATE_SST=True         # should SST update data be downloaded? if False, ignore END_DATE and UPDATE_INTERVAL
END_DATE='1975-11-11'    # end date for simulation (YYYY-MM-DD), NOTE: only used for SST updates
UPDATE_INTERVAL='6'      # how frequently are SSTs updated each day

# set coordinates for GRIB data
NORTH='90'                 # NORTH=90 for global
WEST='-180'                # WEST=-180 for global
SOUTH='-90'                # SOUTH=-90 for global
EAST='180'                 # EAST=180 for global

# print a summary of conditions to termianl
def globals_summary():
    """
    Function prints a summary of all globals in the download request
    """
    print(f"{BOLD}REQUESTED ERA5 DATA SUMMARY:{END}\n")

    summary_lines = [
        ("INIT DATE:",        f"{START_DATE}, {START_HOUR}Z"),
        ("NORTH:",            NORTH),
        ("WEST:",             WEST),
        ("SOUTH:",            SOUTH),
        ("EAST:",             EAST),
        ("SST UPDATES:",      "YES" if UPDATE_SST else "NO")
    ]

    if UPDATE_SST:
        summary_lines.extend([
            ("SIM END DATE:",     END_DATE),
            ("UPDATE INTERVAL:",  f"{UPDATE_INTERVAL} hrs")
        ])

    for label, value in summary_lines:
        print(f"{BOLD}{label:<16}{END} {value}")

def get_surface_data(outpath, start=START_DATE, n=NORTH, w=WEST,
                        s=SOUTH, e=EAST, hh=START_HOUR):
    """
    Function details CDS API request to get all needed surface data
    for a WRF or MPAS run.

    Parameters
    ----------
    outpath : str
        directory to output the data
    start : str
        start date in YYYY-MM-DD format
    n, w, s, e : str
        north, west, south, east location in degrees (-180/90 to 180/90)
    hh : str
        start hour in HH format
    """
    c = cdsapi.Client() # open the CDS API client

    # First get surface data
    print(f'{BOLD}Downloading surface data{END}')
    c.retrieve(
        'reanalysis-era5-single-levels',
        {
            'product_type':'reanalysis',
            'format':'grib',
            'variable':[
                '10m_u_component_of_wind','10m_v_component_of_wind',
                '2m_dewpoint_temperature','2m_temperature',
                'land_sea_mask','mean_sea_level_pressure',
                'sea_ice_cover','sea_surface_temperature',
                'skin_temperature','snow_depth',
                'soil_temperature_level_1','soil_temperature_level_2',
                'soil_temperature_level_3','soil_temperature_level_4',
                'surface_pressure','volumetric_soil_water_layer_1',
                'volumetric_soil_water_layer_2','volumetric_soil_water_layer_3',
                'volumetric_soil_water_layer_4'
            ],
            'date':start,
            'area':f'{n}/{w}/{s}/{e}',
            'time':hh,
        },
        f'{outpath}/ERA5-{start}-{hh}00_SFC.grib')
    
def get_vertical_data(outpath, start=START_DATE, n=NORTH, w=WEST,
                        s=SOUTH, e=EAST, hh=START_HOUR):
    """
    Function details CDS API request to get all needed vertical level data
    for a WRF or MPAS run.

    Parameters
    ----------
    outpath : str
        directory to output the data
    start : str
        start date in YYYY-MM-DD format
    n, w, s, e : str
        north, west, south, east location in degrees (-180/90 to 180/90)
    hh : str
        start hour in HH format
    """
    c = cdsapi.Client() # open the CDS API client

    # First get surface data
    print(f'{BOLD}Downloading data on pressure levels{END}')
    c.retrieve(
        'reanalysis-era5-pressure-levels',
        {
            'product_type':'reanalysis',
            'format':'grib',
            'pressure_level':[
            '1','2','3',
            '5','7','10',
            '20','30','50',
            '70','100','125',
            '150','175','200',
            '225','250','300',
            '350','400','450',
            '500','550','600',
            '650','700','750',
            '775','800','825',
            '850','875','900',
            '925','950','975',
            '1000'
            ],
            'variable':[
            'geopotential','relative_humidity',
            'specific_humidity','temperature',
            'u_component_of_wind','v_component_of_wind'
            ],
            'date':start,
            'area':f'{n}/{w}/{s}/{e}',
            'time':hh,
        },
        f'{outpath}/ERA5-{start}-{hh}00_PL.grib')    

def get_sst_data(outpath, start=START_DATE, end=END_DATE, n=NORTH, w=WEST,
                        s=SOUTH, e=EAST, hh=START_HOUR, interv=UPDATE_INTERVAL):
    """
    Function details CDS API request to get all needed data
    to prescribe SST updates for a WRF or MPAS run.

    Parameters
    ----------
    outpath : str
        directory to output the data
    start : str
        start date in YYYY-MM-DD format
    end : str
        end date in YYYY-MM-DD format
    n, w, s, e : str
        north, west, south, east location in degrees (-180/90 to 180/90)
    hh : str
        start hour in HH format
    interv : str
        interval to download SSTs at
    """
    c = cdsapi.Client() # open the CDS API client

    # First get surface data
    print(f'{BOLD}Downloading SST data{END}')
    c.retrieve(
        'reanalysis-era5-single-levels',
        {
            'product_type':'reanalysis',
            'format':'grib',
            'variable':['land_sea_mask','sea_ice_cover','sea_surface_temperature'],
            'date':f'{start}/{end}',
            'area':f'{n}/{w}/{s}/{e}',
            'time':f'00/to/23/by/{interv}',
        },
        f'{outpath}/SST_ERA5-{start}_to_{end}.grib')

def main():
    """
    Main function to download all data for a specific ERA5 run
    """
    # check CDS API is configured properly
    if not os.path.exists(Path.home() / '.cdsapirc'):
        print("ERROR: No .cdsapirc file found in home directory.")
        exit(1)

    # create output directory
    output_dir= f'{OUTPATH}/{START_DATE}_{END_DATE}'

    print(f"Storing output at: {output_dir}")
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    # print a summary of the request to terminal
    globals_summary()

    # download data
    get_surface_data(output_dir)
    get_vertical_data(output_dir)
    if UPDATE_SST:
        get_sst_data(output_dir)
    
    print('download complete!')

if __name__ == "__main__":
    main()




