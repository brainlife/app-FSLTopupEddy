[![Abcdspec-compliant](https://img.shields.io/badge/ABCD_Spec-v1.1-green.svg)](https://github.com/brainlife/abcd-spec)
[![Run on Brainlife.io](https://img.shields.io/badge/Brainlife-brainlife.app.887-blue.svg)](https://doi.org/10.25663/brainlife.app.887)

# FSL Topup, Eddy Cuda and QC

This application preprocesses diffusion-weighted MRI (DWI) data using **FSL**’s *topup* and *eddy* tools to correct for:

* Susceptibility-induced geometric distortions
* Subject motion
* Eddy-current–related artifacts

The workflow supports either:

* **Reverse phase-encoded DWI acquisitions**, or
* **Dedicated AP/PA EPI field-map volumes**

and produces motion- and distortion-corrected DWI data together with a corresponding brain mask.

All relevant configuration parameters for *topup* and *eddy* are exposed to the user.

---

## Authors

* Gabriele Amorosino — [g.amorosino@gmail.com](mailto:g.amorosino@gmail.com)
* Brad Caron — [bacaron245@gmail.com](mailto:bacaron245@gmail.com )

### Contributors

* Soichi Hayashi — [hayashis@iu.edu](mailto:hayashis@iu.edu)

---

### Funding 

[![NSF-BCS-1734853](https://img.shields.io/badge/NSF_BCS-1734853-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1734853)
[![NSF-BCS-1636893](https://img.shields.io/badge/NSF_BCS-1636893-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1636893)
[![NSF-ACI-1916518](https://img.shields.io/badge/NSF_ACI-1916518-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1916518)
[![NSF-IIS-1912270](https://img.shields.io/badge/NSF_IIS-1912270-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1912270)
[![NIH-NIBIB-R01EB029272](https://img.shields.io/badge/NIH_NIBIB-R01EB029272-green.svg)](https://grantome.com/grant/NIH/R01-EB029272-01)
[![NIH-NINDS-US24NS140384](https://img.shields.io/badge/NIH_NINDS-US24NS140384-green.svg)](https://reporter.nih.gov/search/OwP3wLYKIkGQ3uS2ODPUYw/project-details/11033905)
[![NIH-NINDS-UM1NS122207](https://img.shields.io/badge/NIH_NINDS-UM1NS1222074-green.svg)](https://reporter.nih.gov/search/pRbkN1_vbUmz-GTMYDjwMw/project-details/10664257)
---

Please cite the following foundational works when publishing results generated using this application.

1. Smith SM, Jenkinson M,... & Matthews PM. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage. 2004;23(S1):208–219.
2. Andersson JLR, Skare S, Ashburner J. How to correct susceptibility distortions in spin-echo echo-planar images: application to diffusion tensor imaging.
NeuroImage. 2003;20(2):870–888.
3. Andersson JLR, Sotiropoulos SN. An integrated approach to correction for off-resonance effects and subject movement in diffusion MR imaging.
NeuroImage. 2016;125:1063–1078.
4. Hayashi, S., Caron, B. A., ... & Pestilli, F. (2024). brainlife. io: A decentralized and open-source cloud platform to support neuroscience research. Nature methods, 21(5), 809-813.

Optional method-specific citations

Please additionally cite the following works when the corresponding EDDY features are used:

Outlier detection and replacement (--repol)

Andersson JLR, Graham MS, Zsoldos E, Sotiropoulos SN.
Incorporating outlier detection and replacement into a non-parametric framework for movement and distortion correction of diffusion MR images.
NeuroImage. 2016;141:556–572.

Slice-to-volume motion correction (--mporder)

Andersson JLR, Graham MS, Drobnjak I, Zhang H, Filippini N, Bastiani M.
Towards a comprehensive framework for movement and distortion correction of diffusion MR images: Within-volume movement.
NeuroImage. 2017;152:450–466.

Susceptibility-by-movement correction (--estimate_move_by_susceptibility)

Andersson JLR, Graham MS, Drobnjak I, Zhang H, Campbell J.
Susceptibility-induced distortion that varies due to motion: Correction in diffusion MR without acquiring additional data.
NeuroImage. 2018;171:277–295.


---

# Overview of the Processing Workflow

The pipeline performs the following steps:

1. **TOPUP estimation**

   * Uses either reverse phase-encoded DWI *b0* volumes or AP/PA EPI field maps.
   * Computes the susceptibility distortion field.

2. **EDDY correction**

   * Applies TOPUP distortion correction.
   * Corrects for motion and eddy currents.
   * Optionally merges both phase-encoding acquisitions or processes only the primary DWI series.

3. **Mask generation**

   * Produces a brain mask from the corrected mean *b0* image.
   * 
4. **EDDY QC**

   * Runs `eddy_quad` on the corrected DWI output.
   * Stores QC reports separately without modifying the final DWI outputs.

5. **Regressor generation**

   * Extracts EDDY motion and EC parameters.
   * Produces a tab-separated regressor table for downstream analyses.
---

# Running the App

## On Brainlife.io

Execute directly via:

[https://doi.org/10.25663/brainlife.app.887](https://doi.org/10.25663/brainlife.app.887)

All dependencies are handled automatically by the platform.

---

## Running Locally

### 1. Clone the repository

```bash
git clone https://github.com/gamorosino/app-FSLTopupEddy.git
cd app-FSLTopupEddy
```

---

### 2. Create `config.json`

Example minimal configuration using reverse phase-encoded DWI:

```json
{
  "diff": "testdata/diff/dwi.nii.gz",
  "bval": "testdata/diff/dwi.bvals",
  "bvec": "testdata/diff/dwi.bvecs",

  "rdif": "testdata/rdif/dwi.nii.gz",
  "rbvl": "testdata/rdif/dwi.bvals",
  "rbvc": "testdata/rdif/dwi.bvecs"
}
```

Alternatively, AP/PA **EPI field maps** may be provided instead of `rdif`.
```json
{
  "diff": "testdata/diff/dwi.nii.gz",
  "bval": "testdata/diff/dwi.bvals",
  "bvec": "testdata/diff/dwi.bvecs",

  "epi1": "testdata/epi/AP_epi.nii.gz",
  "epi1_json": "testdata/epi/AP_epi.json",

  "epi2": "testdata/epi/PA_epi.nii.gz",
  "epi2_json": "testdata/epi/PA_epi.json"
}
```
---

### 3. Run the pipeline

```bash
./main
```

---

# Inputs

The application accepts:

### Required

* Primary DWI volume (`diff`)
* Corresponding **b-values** (`bval`)
* Corresponding **b-vectors** (`bvec`)

### Optional (TOPUP source)

One of the following must be provided:

**A. Reverse phase-encoded DWI**

* `rdif`, `rbvl`, `rbvc`

**B. AP/PA EPI field maps**

* `epi1`, `epi2`
* Associated JSON metadata with

  * `PhaseEncodingDirection`
  * `TotalReadoutTime`

---

# Outputs

### Main outputs

* Corrected DWI volume

  ```
  dwi/dwi.nii.gz
  ```
* Rotated diffusion gradients

  ```
  dwi/dwi.bvecs
  ```
* Corrected b-values

  ```
  dwi/dwi.bvals
  ```
* Brain mask

  ```
  mask/mask.nii.gz
  ```
### Quality-control outputs

* EDDY QUAD report

  ```text
  qc/eddy_quad/out/
---

# Dependencies

## Brainlife execution

All software dependencies are managed automatically.

---

## Local execution

Only the following is required:

* **Singularity / Apptainer**

All neuroimaging tools — including **FSL (topup, eddy)**  — are bundled inside the container.
No local installation of FSL is necessary.


---

# Reproducibility

This application is fully containerized, ensuring:

* Deterministic software environment
* Version-controlled preprocessing
* Cross-platform reproducibility

across Brainlife and local execution.
