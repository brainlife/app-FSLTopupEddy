[![Abcdspec-compliant](https://img.shields.io/badge/ABCD_Spec-v1.1-green.svg)](https://github.com/brain-life/abcd-spec)
[![Run on Brainlife.io](https://img.shields.io/badge/Brainlife-brainlife.app.287-blue.svg)](https://doi.org/10.25663/brainlife.app.286)

# FSL Top-up & Eddy - CUDA 

This app will preprocess a DWI image using FSL's topup and eddy functions. This app takes in two sets of reverse phase encoding DWI datatypes as inputs and will output a motion and susceptibility corrected DWI datatype.
This app exposes all the possible flags for topup and eddy and runs via CUDA. Please view user guides provided by FSL for a description of these inputs. The user can also specify whether to merge both phase-encoding images or use the first inputted phase encoding image. 

### Authors 

- Brad Caron (bacaron@iu.edu) 

### Contributors 

- Soichi Hayashi (hayashis@iu.edu) 

### Funding 

[![NSF-BCS-1734853](https://img.shields.io/badge/NSF_BCS-1734853-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1734853)
[![NSF-BCS-1636893](https://img.shields.io/badge/NSF_BCS-1636893-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1636893)
[![NSF-ACI-1916518](https://img.shields.io/badge/NSF_ACI-1916518-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1916518)
[![NSF-IIS-1912270](https://img.shields.io/badge/NSF_IIS-1912270-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1912270)
[![NIH-NIBIB-R01EB029272](https://img.shields.io/badge/NIH_NIBIB-R01EB029272-green.svg)](https://grantome.com/grant/NIH/R01-EB029272-01)

### Citations 

Please cite the following articles when publishing papers that used data, code or other resources created by the brainlife.io community. 

1. J.L.R. Andersson, S. Skare, J. Ashburner. How to correct susceptibility distortions in spin-echo echo-planar images: application to diffusion tensor imaging. NeuroImage, 20(2):870-888, 2003.
2. S.M. Smith, M. Jenkinson, M.W. Woolrich, C.F. Beckmann, T.E.J. Behrens, H. Johansen-Berg, P.R. Bannister, M. De Luca, I. Drobnjak, D.E. Flitney, R. Niazy, J. Saunders, J. Vickers, Y. Zhang, N. De Stefano, J.M. Brady, and P.M. Matthews. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 23(S1):208-219, 2004.
3. M.S. Graham, I. Drobnjak, H. Zhang. Quantitative assessment of the susceptibility artefact and its interaction with motion in diffusion MRI. PLoS ONE, 12(10), 2017.
4. Jesper L. R. Andersson and Stamatios N. Sotiropoulos. An integrated approach to correction for off-resonance effects and subject movement in diffusion MR imaging. NeuroImage, 125:1063-1078, 2016.
5. Jesper L. R. Andersson, Mark S. Graham, Eniko Zsoldos and Stamatios N. Sotiropoulos. Incorporating outlier detection and replacement into a non-parametric framework for movement and distortion correction of diffusion MR images. NeuroImage, 141:556-572, 2016.
6. Jesper L. R. Andersson, Mark S. Graham, Ivana Drobnjak, Hui Zhang, Nicola Filippini and Matteo Bastiani. Towards a comprehensive framework for movement and distortion correction of diffusion MR images: Within volume movement. NeuroImage, 152:450-466, 2017.
7. Jesper L. R. Andersson, Mark S. Graham, Ivana Drobnjak, Hui Zhang and Jon Campbell. Susceptibility-induced distortion that varies due to motion: Correction in diffusion MR without acquiring additional data. NeuroImage, 171:277-295, 2018. 

## Running the App 

### On Brainlife.io 

You can submit this App online at [https://doi.org/10.25663/brainlife.app.286](https://doi.org/10.25663/brainlife.app.286) via the 'Execute' tab. 

### Running Locally (on your machine) 

1. git clone this repo 

2. Inside the cloned directory, create `config.json` with something like the following content with paths to your input files. 

```json 
{
   "diff":    "testdata/diff/dwi.nii.gz",
    "bval":    "testdata/diff/dwi.bvals",
    "bvec":    "testdata/diff/dwi.bvecs",
    "rdif":    "testdata/rdif/dwi.nii.gz",
    "rbvl":    "testdata/rdif/dwi.bvals",
    "rbvc":    "testdata/rdif/dwi.bvecs",
    "param":    0.0267,
    "encode":    "PA"
} 
``` 

### Sample Datasets 

You can download sample datasets from Brainlife using [Brainlife CLI](https://github.com/brain-life/cli). 

```
npm install -g brainlife 
bl login 
mkdir input 
bl dataset download 
``` 

3. Launch the App by executing 'main' 

```bash 
./main 
``` 

## Output 

The main output of this App is contains a DWI image and a computed brainmask of the DWI data. 

#### Product.json 

The secondary output of this app is `product.json`. This file allows web interfaces, DB and API calls on the results of the processing. 

### Dependencies 

This App requires the following libraries when run locally. 
- FSL: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation
- jsonlab: https://github.com/fangq/jsonlab
- singularity: https://singularity.lbl.gov/quickstart
- CUDA 
