#!/usr/bin/env python3

import os, sys
import pandas as pd
import json

def createRegressors(param_filepath, movement_filepath, restricted_movement_filepath, outpath):

    params = pd.read_csv(param_filepath, sep=r"\s+", header=None)
    rms = pd.read_csv(movement_filepath, sep=r"\s+", header=None)
    rms_restricted = pd.read_csv(restricted_movement_filepath, sep=r"\s+", header=None)

    param_columns = ['trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z']
    param_columns += ['EC' + str(f + 1) for f in range(len(params.columns) - len(param_columns))]
    params.columns = param_columns

    rms.columns = [
        'framewise_displacement_first_volume',
        'framewise_displacement_previous_volume'
    ]

    rms_restricted.columns = [
        'framewise_displacement_restricted_first_volume',
        'framewise_displacement_restricted_previous_volume'
    ]

    out_df = pd.concat([params, rms, rms_restricted], axis=1)
    out_df.to_csv(outpath, sep="\t", index=False)

def main():

    top_path = './eddy_quad'

    outpath = 'regressors'
    if not os.path.isdir(outpath):
        os.mkdir(outpath)

    param_filepath = top_path + '/eddy_corrected_data.eddy_parameters'
    rms_filepath = top_path + '/eddy_corrected_data.eddy_movement_rms'
    rms_restricted_filepath = top_path + '/eddy_corrected_data.eddy_restricted_movement_rms'

    createRegressors(
        param_filepath,
        rms_filepath,
        rms_restricted_filepath,
        outpath + '/regressors.tsv'
    )

if __name__ == '__main__':
    main()
