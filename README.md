# Remote Sensing and GIS

Interactive Shiny lecture with 10 questions. Results are stored only in each browser session and can be downloaded as CSV. 

## Repository structure

```text
.
├── app.R
├── Dockerfile
├── install.R
├── start
├── runtime.txt
├── .gitignore
├── image/
│   ├── rgb_image.tif
│   ├── multispectral_image.tif
│   ├── hyper.tif
│   └── wavelengths.csv
└── README.md
```

## Required image files

Add these files to `image/` before pushing to GitHub:

- `rgb_image.tif`
- `multispectral_image.tif`
- `hyper.tif`
- `wavelengths.csv`

The wavelength CSV must have a column named `wavelength_nm` with one row per hyperspectral band.

## Run locally

```r
install.packages(c("shiny", "shinyjs", "plotly", "terra"))
shiny::runApp()
```

## Binder links

### Launch browser-based RStudio

```text
https://mybinder.org/v2/gh/pspawar71/remote-sensing-htp-binder/main?urlpath=rstudio
```

## Important Binder behavior

- Each student receives an isolated temporary session.
- Results are stored only in memory for that session.
- Students should download their CSV before closing the session.
- Sessions and generated files may disappear when Binder shuts down.
- Do not upload private or sensitive datasets to a public repository.
- Keep GeoTIFF files small enough for repository and Binder resource limits.
