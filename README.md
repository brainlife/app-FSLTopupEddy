[![Abcdspec-compliant](https://img.shields.io/badge/ABCD_Spec-v1.1-green.svg)](https://github.com/brain-life/abcd-spec)
[![Run on Brainlife.io](https://img.shields.io/badge/Brainlife-brainlife.app.155-blue.svg)](https://doi.org/10.25663/brainlife.app.155)

# app-FSLTopupEddy
This app will correct for phase-encoding, eddy current, and motion artifacts in DWI images using FSL's Top-up and Eddy functions. Inputs are reverse-phase encoded DWI images (x2), and the outputs are a corrected DWI datatype and a brainmask datatype.

### Authors
- Brad Caron (bacaron@iu.edu)

### Contributors
- Soichi Hayashi (hayashi@iu.edu)
- Franco Pestilli (franpest@indiana.edu)
- Brent McPherson (bcmcpher@iu.edu)

### Funding
[![NSF-BCS-1734853](https://img.shields.io/badge/NSF_BCS-1734853-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1734853)
[![NSF-BCS-1636893](https://img.shields.io/badge/NSF_BCS-1636893-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1636893)

## Running the App 

### On Brainlife.io

You can submit this App online at [https://doi.org/10.25663/brainlife.app.155](https://doi.org/10.25663/bl.app.155) via the "Execute" tab.

### Running Locally (on your machine)

1. git clone this repo.
2. Inside the cloned directory, create `config.json` with something like the following content with paths to your input files.

```json
{
        "diff": "./input/dwi1/dwi.nii.gz",
        "bval": "./input/dwi1/dwi.bvals",
        "bvec": "./input/dwi1/dwi.bvecs",
        "rdif": "./input/dwi2/dwi.nii.gz",
        "rbvc": "./input/dwi2/dwi.bvecs",
        "rbvl": "./input/dwi2/dwi.bvals",
        "param":  0.00006999,
        "encode": "PA"
}
```

### Sample Datasets

You can download sample datasets from Brainlife using [Brainlife CLI](https://github.com/brain-life/cli).

```
npm install -g brainlife
bl login
mkdir input
bl dataset download 5b96bbf2059cf900271924f3 && mv 5b96bbf2059cf900271924f3 input/dwi1
bl dataset download 5b96bbf2059cf900271924f3 && mv 5b96bbf2059cf900271924f3 input/dwi2

```


3. Launch the App by executing `main`

```bash
./main
```

## Output

The main output of this App is DWI datatype and a mask datatype.

#### Product.json
The secondary output of this app is `product.json`. This file allows web interfaces, DB and API calls on the results of the processing. 

### Dependencies

This App requires the following libraries when run locally.

  - singularity: https://singularity.lbl.gov/
  - FSL: https://hub.docker.com/r/brainlife/fsl/tags/5.0.9
  - jsonlab: https://github.com/fangq/jsonlab.git
