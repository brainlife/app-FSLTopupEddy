<h1 align="center">FSL Top-up &amp; Eddy</h1>

<p align="center">
  Susceptibility, eddy-current and motion correction of diffusion-weighted images with FSL topup, eddy and eddy_correct.
</p>

<p align="center">
  <a href="https://github.com/brainlife/abcd-spec"><img src="https://img.shields.io/badge/ABCD_Spec-v1.1-green.svg" alt="ABCD Spec v1.1"></a>
  <a href="https://doi.org/10.25663/brainlife.app.662"><img src="https://img.shields.io/badge/Brainlife-brainlife.app.662-blue.svg" alt="Run on brainlife.io"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" alt="MIT license"></a>
</p>

## 🧠 At a glance

<!-- brainlife-app:begin (generated from the App manifest; edit the manifest, not this block) -->

> **Estimates the susceptibility field from reverse phase-encoded b0s with FSL topup and corrects eddy currents and motion with FSL eddy_correct, exposing topup's options.**

Merges the mean b0 of each phase-encoding series, runs FSL topup with the chosen options, then runs eddy_correct on the DWI against refvol and rotates the bvecs; a brain mask is made with bet. Set reslice when the two series differ in slice count (FreeSurfer mri_vol2vol reslices rdiff to diff). Note: the topup field is estimated but not applied to the DWI by eddy_correct, and topup_eddy.sh tests a variable (merge_full) that is never read, so only the first DWI series is corrected.

| | |
|---|---|
| 📥 **Inputs** | `neuro/dwi` ×2 |
| 📤 **Outputs** | `neuro/dwi` · `neuro/mask` · `raw` |
| 🐳 **Container** | `brainlife/mrtrix3:3.0_RC3` |
| ⚙️ **Resources** | 8 CPUs · 3 h walltime |
| 🔑 **Requires** | `FREESURFER_LICENSE` |
| 🔗 **Run it** | [doi.org/10.25663/brainlife.app.662](https://doi.org/10.25663/brainlife.app.662) |

#### 📥 Inputs

| Input | Datatype | Required | Description |
|---|---|---|---|
| `diff` | `neuro/dwi` | yes | DWI acquired in the primary phase-encoding direction, with bvecs and bvals. |
| `rdiff` | `neuro/dwi` | yes | DWI acquired with the reversed phase-encoding direction, with bvecs and bvals. Must have the same number of slices as diff unless reslice is set. |

#### 📤 Outputs

| Output | Datatype | Description |
|---|---|---|
| `dwi` | `neuro/dwi` | DWI after eddy_correct, with rotated bvecs and bvals. |
| `mask` | `neuro/mask` | Brain mask of the corrected DWI (FSL bet). |
| `raw` | `raw` | Derivatives: eddy_correct log, topup results and field, merged b0 images, index.txt and acq_params.txt. |

<details>
<summary><b>⚙️ Parameters</b> (19)</summary>

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
| `reslice` | boolean | `false` | If, for whatever reason, the two DWI images do not hae the same number of slices, set reslice to true and it will reslice the rdif image to diff |

</details>

<!-- brainlife-app:end -->

## 🏷️ Versions on brainlife.io

This repository hosts five Apps, each built from its own branch. Pick the one that matches your data:

| App | Inputs | Branch | Run it | Status |
|---|---|---|---|---|
| FSL Top-up & Eddy Correct | two DWIs, opposite phase encoding | [`topup-eddy_correct-v1.0`](https://github.com/brainlife/app-FSLTopupEddy/tree/topup-eddy_correct-v1.0) | [doi:10.25663/brainlife.app.662](https://doi.org/10.25663/brainlife.app.662) | current |
| FSL Eddy (CUDA) | one DWI | [`eddy-only-cuda-v1.0`](https://github.com/brainlife/app-FSLTopupEddy/tree/eddy-only-cuda-v1.0) | [doi:10.25663/brainlife.app.544](https://doi.org/10.25663/brainlife.app.544) | available |
| FSL Eddy (OpenMP) | one DWI | [`eddy-only-v1.0`](https://github.com/brainlife/app-FSLTopupEddy/tree/eddy-only-v1.0) | [doi:10.25663/brainlife.app.543](https://doi.org/10.25663/brainlife.app.543) | available |
| FSL Eddy-correct | one DWI | [`eddy-correct-v1.0`](https://github.com/brainlife/app-FSLTopupEddy/tree/eddy-correct-v1.0) | [doi:10.25663/brainlife.app.542](https://doi.org/10.25663/brainlife.app.542) | available |
| FSL Top-up & Eddy | two DWIs, opposite phase encoding | [`1.1`](https://github.com/brainlife/app-FSLTopupEddy/tree/1.1) | [doi:10.25663/brainlife.app.155](https://doi.org/10.25663/brainlife.app.155) | available |

- **FSL Top-up & Eddy** (`1.1`): merges the b0 volumes of both phase-encoding series, estimates the susceptibility field with `topup` (`b02b0.cnf`), runs `eddy_openmp` with `--repol` on the concatenated series and rotates the bvecs; a brain mask of the corrected DWI is made with `bet`. Use it when you have a reverse phase-encoded DWI. In this branch the encoding-direction test is always true, so `acq_params.txt` is always written for PA/AP whatever the `encode` setting.
- **FSL Top-up & Eddy Correct** (`topup-eddy_correct-v1.0`): runs `topup` on the mean b0 of each series with all of topup's options exposed, then `eddy_correct` on the DWI against `refvol`, rotates the bvecs and makes a brain mask with `bet`. Set `reslice` when the two series differ in slice count (FreeSurfer `mri_vol2vol` reslices `rdiff` to `diff`). Note that in this branch the topup field is estimated but not applied to the DWI, and `mergefull` has no effect, so only the first series (`diff`) is corrected.
- **FSL Eddy (OpenMP)** (`eddy-only-v1.0`) and **FSL Eddy (CUDA)** (`eddy-only-cuda-v1.0`): for a single phase-encoding DWI. They build a b0 brain mask, write `acq_params.txt` from `encode` and `param`, run `eddy_openmp` or `eddy_cuda9.1` with `--cnr_maps` and all of eddy's options exposed (multiband, outlier replacement, slice-to-volume and susceptibility-by-movement correction, …), then `eddy_quad` for QC. The CUDA App is much faster and is needed for slice-to-volume correction (`mporder` > 0); it needs a GPU node.
- **FSL Eddy-correct** (`eddy-correct-v1.0`): FSL `eddy_correct` (affine registration to the `refvol` volume) and bvec rotation with `fdt_rotate_bvecs`. Use it for data that were already corrected with topup or cannot be; FSL eddy is the more complete alternative.

## 🚀 Running the App

### ☁️ On brainlife.io

Open the App at [doi.org/10.25663/brainlife.app.662](https://doi.org/10.25663/brainlife.app.662), or one of the other Apps above, and choose your `neuro/dwi` dataset(s): `diff`, the first DWI, and for the topup Apps `rdiff`, the DWI with the opposite phase encoding. Set:

- `encode`: the phase encoding direction of the first DWI (`diff`, not `rdiff`): `PA`, `AP`, `LR` or `RL`;
- `param`: the dwell time (total readout time) used in `acq_params.txt`; see the [FSL eddy FAQ](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/Faq#How_do_I_know_what_to_put_into_my_--acqp_file).

The other options map directly onto those of FSL [topup](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup) and [eddy](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy); see the FSL user guides for what they do. Press **Execute**. The corrected DWI is archived to your project as a `neuro/dwi` dataset, with a DWI brain mask (`neuro/mask`) for the topup Apps and QC and intermediate files as `raw` datasets.

### 💻 Locally

You need [Singularity/Apptainer](https://apptainer.org/) and [`jq`](https://jqlang.github.io/jq/). The Apps run in the `brainlife/mrtrix3:3.0_RC3` container (which provides FSL); the eddy-only OpenMP App also uses `brainlife/fsl:6.0.4-patched` for `eddy_quad`, the CUDA App needs an NVIDIA GPU, and `reslice` needs a [FreeSurfer license](https://surfer.nmr.mgh.harvard.edu/registration.html).

1. Clone this repository and check out the branch of the App you want, for example `git checkout topup-eddy_correct-v1.0`.
2. Create `config.json` with the paths to your inputs and the options you want. For the topup Apps:

   ```json
   {
       "diff": "/input/diff/dwi.nii.gz",
       "bval": "/input/diff/dwi.bvals",
       "bvec": "/input/diff/dwi.bvecs",
       "rdif": "/input/rdif/dwi.nii.gz",
       "rbvl": "/input/rdif/dwi.bvals",
       "rbvc": "/input/rdif/dwi.bvecs",
       "param": 0.0267,
       "encode": "PA"
   }
   ```

   The topup-eddy_correct App also reads the topup options (`warpres`, `subsamp`, `fwhm`, `miter`, `lambda`, `ssqlambda`, `regmod`, `estmov`, `minmet`, `splineorder`, `numprec`, `interp`, `scale`, `regrid`), `refvol` and `reslice`. The single-DWI Apps take the DWI under `dwi`, `bvecs` and `bvals` instead.

3. Run the App (export `FREESURFER_LICENSE` first if you set `reslice`):

   ```bash
   ./main
   ```

## 📦 Outputs

```text
dwi/
├── dwi.nii.gz     the corrected DWI
├── dwi.bvals
└── dwi.bvecs      rotated gradient directions
mask/
└── mask.nii.gz    brain mask of the corrected DWI (topup Apps)
raw/               intermediate files, eddy parameters and eddy_correct logs
```

The eddy-only Apps write the corrected DWI under `output/` and the `eddy_quad` QC report as a separate output; the OpenMP App also writes a table of motion regressors.

## 🩺 Troubleshooting

- **`output missing`** or **`something went wrong. check derivatives and logs`**: the corrected DWI was not produced. Check the topup and eddy (or eddy_correct) output in the log, and confirm both DWI series have matching dimensions (or set `reslice`).
- **`Please set FREESURFER_LICENSE in .bashrc`**: `reslice` is set and no FreeSurfer license is configured. Provide a license, or leave `reslice` off.
- **CUDA App fails**: the job needs a node with a CUDA GPU.

## 📚 Citing

> [!TIP]
> If you use this App in your work, please cite the App, the software it builds on and brainlife.io (below). GitHub's **Cite this repository** button gives the App citation in APA and BibTeX.

- Andersson JLR, Skare S, Ashburner J. How to correct susceptibility distortions in spin-echo echo-planar images: application to diffusion tensor imaging. *NeuroImage* 20(2):870–888 (2003).
- Smith SM, Jenkinson M, Woolrich MW, Beckmann CF, Behrens TEJ, Johansen-Berg H, Bannister PR, De Luca M, Drobnjak I, Flitney DE, Niazy R, Saunders J, Vickers J, Zhang Y, De Stefano N, Brady JM, Matthews PM. Advances in functional and structural MR image analysis and implementation as FSL. *NeuroImage* 23(S1):208–219 (2004).
- Graham MS, Drobnjak I, Zhang H. Quantitative assessment of the susceptibility artefact and its interaction with motion in diffusion MRI. *PLoS ONE* 12(10) (2017).
- Andersson JLR, Sotiropoulos SN. An integrated approach to correction for off-resonance effects and subject movement in diffusion MR imaging. *NeuroImage* 125:1063–1078 (2016).
- Andersson JLR, Graham MS, Zsoldos E, Sotiropoulos SN. Incorporating outlier detection and replacement into a non-parametric framework for movement and distortion correction of diffusion MR images. *NeuroImage* 141:556–572 (2016).
- Andersson JLR, Graham MS, Drobnjak I, Zhang H, Filippini N, Bastiani M. Towards a comprehensive framework for movement and distortion correction of diffusion MR images: within volume movement. *NeuroImage* 152:450–466 (2017).
- Andersson JLR, Graham MS, Drobnjak I, Zhang H, Campbell J. Susceptibility-induced distortion that varies due to motion: correction in diffusion MR without acquiring additional data. *NeuroImage* 171:277–295 (2018).
- FSL Top-up & Eddy Correct. brainlife.io App. [doi:10.25663/brainlife.app.662](https://doi.org/10.25663/brainlife.app.662)
- Andersson JLR, Skare S, Ashburner J. How to correct susceptibility distortions in spin-echo echo-planar images: application to diffusion tensor imaging. NeuroImage 20(2):870-888 (2003).
- Smith SM, Jenkinson M, Woolrich MW, et al. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage 23(S1):208-219 (2004).
- Fischl. FreeSurfer. *NeuroImage* 62:774-781 (2012). [doi:10.1016/j.neuroimage.2012.01.021](https://doi.org/10.1016/j.neuroimage.2012.01.021)
- Jenkinson et al. FSL. *NeuroImage* 62:782-790 (2012). [doi:10.1016/j.neuroimage.2011.09.015](https://doi.org/10.1016/j.neuroimage.2011.09.015)
- Tournier et al. MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. *NeuroImage* 202:116137 (2019). [doi:10.1016/j.neuroimage.2019.116137](https://doi.org/10.1016/j.neuroimage.2019.116137)
- Hayashi S, Caron BA, Heinsfeld AS, et al. brainlife.io: a decentralized and open-source cloud platform to support neuroscience research. *Nature Methods* 21:809–813 (2024). [doi:10.1038/s41592-024-02237-2](https://doi.org/10.1038/s41592-024-02237-2)
- Avesani P, McPherson B, Hayashi S, et al. The open diffusion data derivatives, brain data upcycling via integrated publishing of derivatives and reproducible open cloud services. *Scientific Data* 6:69 (2019). [doi:10.1038/s41597-019-0073-y](https://doi.org/10.1038/s41597-019-0073-y)

## 👥 Authors

- Brad Caron

**Contributors:** Soichi Hayashi

## 💰 Funding

[![Wellcome-226486/Z/22/Z](https://img.shields.io/badge/Wellcome-226486%2FZ%2F22%2FZ-purple.svg)](https://wellcome.org/)
[![NIH-NINDS-U24NS140384](https://img.shields.io/badge/NIH_NINDS-U24NS140384-green.svg)](https://reporter.nih.gov/project-details/11261037)
[![NIH-NINDS-UM1NS132207](https://img.shields.io/badge/NIH_NINDS-UM1NS132207-green.svg)](https://reporter.nih.gov/project-details/11411328)
[![NIH-NIBIB-R01EB029272](https://img.shields.io/badge/NIH_NIBIB-R01EB029272-green.svg)](https://reporter.nih.gov/project-details/10262925)
[![NIH-NIBIB-R01EB030896](https://img.shields.io/badge/NIH_NIBIB-R01EB030896-green.svg)](https://reporter.nih.gov/project-details/10428625)
[![NIH-NIMH-R01MH126699](https://img.shields.io/badge/NIH_NIMH-R01MH126699-green.svg)](https://reporter.nih.gov/project-details/10460628)
[![NIH-NIDCD-R01DC020088](https://img.shields.io/badge/NIH_NIDCD-R01DC020088-green.svg)](https://reporter.nih.gov/project-details/11140284)
[![NSF-BCS-1734853](https://img.shields.io/badge/NSF_BCS-1734853-blue.svg)](https://www.nsf.gov/awardsearch/showAward?AWD_ID=1734853)
[![NSF-BCS-2203524](https://img.shields.io/badge/NSF_BCS-2203524-blue.svg)](https://www.nsf.gov/awardsearch/showAward?AWD_ID=2203524)
[![NSF-IIS-1636893](https://img.shields.io/badge/NSF_IIS-1636893-blue.svg)](https://www.nsf.gov/awardsearch/showAward?AWD_ID=1636893)
[![NSF-OAC-2148729](https://img.shields.io/badge/NSF_OAC-2148729-blue.svg)](https://www.nsf.gov/awardsearch/showAward?AWD_ID=2148729)
[![NSF-IIS-1912270](https://img.shields.io/badge/NSF_IIS-1912270-blue.svg)](https://www.nsf.gov/awardsearch/showAward?AWD_ID=1912270)
[![NSF-IIS-2148700](https://img.shields.io/badge/NSF_IIS-2148700-blue.svg)](https://www.nsf.gov/awardsearch/showAward?AWD_ID=2148700)
[![NSF-OAC-1916518](https://img.shields.io/badge/NSF_OAC-1916518-blue.svg)](https://www.nsf.gov/awardsearch/showAward?AWD_ID=1916518)

<sub>brainlife.io is publicly funded, and acknowledging that support helps keep it running. This App was developed with support from Wellcome, the U.S. National Institutes of Health (including the BRAIN Initiative BRAIN CONNECTS program: The Axonal Projectome EXchange, U24NS140384, and the Center for Mesoscale Connectomics, UM1NS132207) and the U.S. National Science Foundation.</sub>

## ⚖️ License

[MIT](https://github.com/brainlife/app-FSLTopupEddy/blob/1.1/LICENSE). FSL is distributed under its own [license](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence) (non-commercial use).
