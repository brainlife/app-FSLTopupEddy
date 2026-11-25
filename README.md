[![Abcdspec-compliant](https://img.shields.io/badge/ABCD_Spec-v1.1-green.svg)](https://github.com/brain-life/abcd-spec)
[![Run on Brainlife.io](https://img.shields.io/badge/Brainlife-brainlife.app.287-blue.svg)](https://doi.org/10.25663/brainlife.app.286)

# FSL Top-up & Eddy - CUDA 

<!-- brainlife-app:begin (generated from the App manifest; edit the manifest, not this block) -->

**Estimates the susceptibility field from reverse phase-encoded b0s with FSL topup and corrects eddy currents and motion with FSL eddy_correct, exposing topup's options.**

Merges the mean b0 of each phase-encoding series, runs FSL topup with the chosen options, then runs eddy_correct on the DWI against refvol and rotates the bvecs; a brain mask is made with bet. Set reslice when the two series differ in slice count (FreeSurfer mri_vol2vol reslices rdiff to diff). Note: the topup field is estimated but not applied to the DWI by eddy_correct, and topup_eddy.sh tests a variable (merge_full) that is never read, so only the first DWI series is corrected.

Run it on brainlife.io: [https://doi.org/10.25663/brainlife.app.662](https://doi.org/10.25663/brainlife.app.662)

| Input | Datatype | Required | Description |
|---|---|---|---|
| `diff` | `neuro/dwi` | yes | DWI acquired in the primary phase-encoding direction, with bvecs and bvals. |
| `rdiff` | `neuro/dwi` | yes | DWI acquired with the reversed phase-encoding direction, with bvecs and bvals. Must have the same number of slices as diff unless reslice is set. |

| Output | Datatype | Description |
|---|---|---|
| `dwi` | `neuro/dwi` | DWI after eddy_correct, with rotated bvecs and bvals. |
| `mask` | `neuro/mask` | Brain mask of the corrected DWI (FSL bet). |
| `raw` | `raw` | Derivatives: eddy_correct log, topup results and field, merged b0 images, index.txt and acq_params.txt. |

| Parameter | Type | Default | Description |
|---|---|---|---|
| `param` | number |  | This is the 'dwell time'. Please see https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/Faq#How_do_I_know_what_to_put_into_my_--acqp_file for more information about this specific parameter. |
| `encode` | enum | `PA` | Phase encoding direction of the diff (not rdiff), i.e. first, inputted dwi. for example, if the phase encoding direction of the first inputted dwi is 'PA', then select 'PA'. If it was 'AP', then select 'AP' Options: `PA`, `AP`, `LR`, `RL`. |
| `warpres` | string | `20,16,14,12,10,6,4,4,4` | topup: (approximate) resolution (in mm) of warp basis for the different sub-sampling levels |
| `subsamp` | string | `2,2,2,2,2,1,1,1,1` | topup: sub-sampling scheme |
| `fwhm` | string | `8,6,4,3,3,2,1,0,0` | topup: FWHM (in mm) of gaussian smoothing kernel |
| `miter` | string | `5,5,5,5,5,10,10,20,20` | topup: number of iterations |
| `lambda` | string | `0.005,0.001,0.0001,0.000015,0.000005,0.0000005,0.00000005,0.0000000005,0.00000000001` | topup: Weight of regularisation |
| `ssqlambda` | string | `1` | topup: If set (=1), lambda is weighted by current ssq |
| `regmod` | enum | `bending_energy` | topup: Model for regularisation of warp-field Options: `membrane_energy`, `bending_energy`. |
| `estmov` | string | `1,1,1,1,1,0,0,0,0` | topup: Estimate movements if set |
| `minmet` | string | `0,0,0,0,0,1,1,1,1` | topup: Minimisation method 0=Levenberg-Marquardt, 1=Scaled Conjugate Gradient |
| `splineorder` | string | `3` | topup: Order of spline, 2->Qadratic spline, 3->Cubic spline |
| `numprec` | enum | `double` | topup: Precision for representing Hessian, double or float Options: `double`, `float`. |
| `interp` | enum | `spline` | topup: Image interpolation model, linear or spline Options: `linear`, `spline`. |
| `scale` | boolean | `true` | topup: If set (=1), the images are individually scaled to a common mean |
| `regrid` | boolean | `true` | topup: If set (=1), the calculations are done in a different grid |
| `refvol` | string | `0` | Eddy-correct: reference volume to align everything to |
| `mergefull` | boolean | `false` | Intended to merge both phase-encoding series before eddy_correct. Note: topup_eddy.sh tests a variable named merge_full that is never read from config.json, so only the first series (diff) is used in this branch. |
| `reslice` | boolean | `false` | If, for wahtever reason, the two DWI images do not hae the same number of slices, set reslice to true and it will reslice the rdif image to diff |

Runtime: container `brainlife/mrtrix3:3.0_RC3`; 8 CPUs; 3 h walltime; needs `FREESURFER_LICENSE`.

Please cite:
- Andersson JLR, Skare S, Ashburner J. How to correct susceptibility distortions in spin-echo echo-planar images: application to diffusion tensor imaging. NeuroImage 20(2):870-888 (2003).
- Smith SM, Jenkinson M, Woolrich MW, et al. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage 23(S1):208-219 (2004).

<!-- brainlife-app:end -->

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

- FSL: 
- jsonlab: 
- singularity: 
- CUDA 