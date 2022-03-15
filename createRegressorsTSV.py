#!/usr/bin/env python3

import os, sys
import pandas as pd
import json

def createRegressors(param_filepath,movement_filepath,restricted_movement_filepath,outpath):

    # load data
    params = pd.read_table(param_filepath, delimiter="  ", header=None)
    rms = pd.read_table(movement_filepath, delimiter="  ", header=None)
    rms_restricted = pd.read_table(restricted_movement_filepath, delimiter="  ", header=None)

    # update column names
    param_columns = ['trans_x','trans_y','trans_z','rot_x','rot_y','rot_z']
    param_columns = param_columns + [ 'EC'+str(f+1) for f in range(0,len(params.columns) - len(param_columns)) ]
    params.columns = param_columns

    rms_columns = ['framewise_displacement_first_volume','framewise_displacement_previous_volume']
    rms.columns = rms_columns

    rms_restricted_columns = ['framewise_displacement_restricted_first_volume','framewise_displacement_restricted_previous_volume']
    rms_restricted.columns = rms_restricted_columns

    # merge tables together
    out_df = pd.concat([params,rms,rms_restricted],axis=1)

    # output table
    out_df.to_csv(outpath, sep="\t", index=False)

def main():

    # grab eddy top directory
    top_path = './eddy_quad'

    # make outdirectory
    outpath='regressors'
    if not os.path.isdir(outpath):
        os.mkdir(outpath)

    # grab filepaths
    param_filepath = top_path +'/eddy_parameters'
    rms_filepath = top_path +'/eddy_movement_rms'
    rms_restricted_filepath = top_path +'/eddy_restricted_movement_rms'

    # generate regressors .tsv file
    createRegressors(param_filepath, rms_filepath, rms_restricted_filepath,outpath+'/regressors.tsv')

if __name__ == '__main__':
    main()
