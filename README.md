# Remote Sensing and GIS Knowledge Assessment

An interactive, self-paced knowledge assessment for reviewing foundational concepts in **remote sensing**, and **Geographic Information Systems (GIS)**.

Built with **R Shiny**, the application presents 20 questions and image-based learning activities covering RGB, multispectral and hyperspectral imagery, spatial resolution, vegetation indices, spectral signatures, and related remote-sensing and GIS concepts. Learners can complete the assessment independently and download their results as a CSV file.

## Learning objectives

After completing the assessment, learners should be able to:

- Distinguish RGB, multispectral, and hyperspectral imagery.
- Explain how spatial resolution affects image interpretation and analysis.
- Recognize the role of spectral bands and spectral signatures.
- Interpret common vegetation-index concepts.
- Connect remote-sensing measurements with high-throughput crop phenotyping.
- GIS components, data types and basic concepts 
- Apply conceptual knowledge to image-based questions and activities.

## Key features

- **Self-paced learning:** Complete the assessment independently.
- **20-question assessment:** Review important remote-sensing and GIS concepts.
- **Interactive R Shiny interface:** Receive a browser-based learning experience.
- **Image-based activities:** Work with RGB, multispectral, and hyperspectral examples.
- **Downloadable results:** Export assessment results as a CSV file.
- **Session-based privacy:** Results remain within the learner's temporary browser session.
- **Reproducible environment:** Run locally or through a Binder-compatible container.

## Topics covered

The assessment includes questions and activities related to:

- Remote sensing and GIS fundamentals
- RGB and multispectral imagery
- Hyperspectral data and wavelengths
- Spatial resolution
- Spectral signatures
- Vegetation indices
- Image interpretation
- High-throughput phenotyping applications


### Main files

- `app.R`: User interface, server logic, questions, scoring, and result-download functionality.
- `install.R`: Installs the R packages required by the application.
- `Dockerfile`: Defines the container environment used to run the application.
- `start`: Starts the Shiny application in the hosted environment.
- `runtime.txt`: Specifies the required runtime configuration.
- `field.geojson`: Spatial vector data used by the learning activities.
- `image/`: Stores the imagery and wavelength data used by the application.

## Required image files

The following files must be available in the `image/` directory:

```text
image/rgb_image.tif
image/multispectral_image.tif
image/hyper.tif
image/wavelengths.csv
```

The wavelength table must contain a column named:

```text
wavelength_nm
```

The table should include one row for each hyperspectral image band, in the same order as the bands in `hyper.tif`.

## Run the application locally

### 1. Clone the repository

```bash
git clone https://github.com/pspawar71/remote-sensing-htp-binder.git
cd remote-sensing-htp-binder
```

### 2. Install the required R packages

Open R or RStudio and run:

```r
install.packages(c("shiny", "shinyjs", "plotly", "terra"))
```

Alternatively, use the repository's installation script:

```r
source("install.R")
```

### 3. Launch the application

```r
shiny::runApp()
```

R will display a local address. Open that address in a web browser if it does not open automatically.

## Run in Binder (Launch browser-based RStudio)

```text
https://mybinder.org/v2/gh/pspawar71/remote-sensing-htp-binder/main?urlpath=rstudio
```
After RStudio opens, run:

```r
shiny::runApp()
```

## Assessment results and data privacy

- Each learner receives an isolated, temporary session.
- Assessment results are stored only in memory during that session.
- Learners should download their CSV results before closing the session.
- Session data and generated files may disappear when Binder shuts down.
- Do not upload confidential, personal, or sensitive data to the public repository.

## Expected output

At the end of the assessment, learners can download a CSV file containing their recorded responses and results. The file can be used for personal review, course documentation, or instructor-led analysis, subject to the applicable privacy and research requirements.

## Using the assessment in teaching

A suggested instructional sequence is:

1. Introduce the core remote-sensing and HTP concepts.
2. Allow learners to complete the assessment independently.
3. Ask learners to download and review their results.
4. Discuss questions that produced common misunderstandings.
5. Revisit relevant imagery, spectral, or spatial-resolution examples.
6. Repeat selected activities to document improvement.

The application can support classroom instruction, workshops, extension programs, onboarding activities, or independent study.

## Limitations

This application is intended as an educational knowledge assessment. Scores should be interpreted as evidence of performance on the included questions, not as a comprehensive certification of professional competency in remote sensing, GIS, or high-throughput phenotyping.

## Citation

If you use this application in teaching, training, or research, please cite the repository:

> Pawar, P. S. *Remote Sensing and GIS Knowledge Assessment*. GitHub repository. https://github.com/pspawar71/remote-sensing-htp-binder


## Contributing

Suggestions and contributions are welcome:

1. Fork the repository.
2. Create a new branch.
3. Make and test your changes.
4. Submit a pull request describing the improvement.

You can also open a GitHub issue to report a problem, recommend a new question, or suggest an additional learning activity.

## License

See the `LICENSE` file in this repository for the applicable terms of use and distribution.

## Author

**Popat Shivaji Pawar**  
GitHub: [pspawar71](https://github.com/pspawar71)

---

If this assessment supports your teaching or learning, consider starring the repository and sharing it with others working in remote sensing, GIS, or high-throughput phenotyping.




