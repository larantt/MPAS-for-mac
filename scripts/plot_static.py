#!/usr/bin/env python3
"""
Created: Saturday July 5th 2025
Author: Lara Tobias-Tarsh (laratt@umich.edu)

TESTING
Code to plot terrain height of an MPAS static file, intention is to quickly
check if the init_atmosphere_model module to generate static files ran correctly
"""

###############
### IMPORTS ###
###############
import numpy as np
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import xarray as xr
import uxarray as ux

###############
### GLOBALS ###
###############
BASE_PATH = '/Users/laratobias-tarsh/Documents/atmos_models/data/MPAS_meshes' # path to directory
STATIC_NAME = 'x1.10242.static.nc' # name of the static file you want to plot

