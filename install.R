packages <- c(
  "shiny",
  "shinyjs",
  "plotly",
  "terra"
)

missing_packages <- packages[
  !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  install.packages(
    missing_packages,
    repos = "https://cloud.r-project.org",
    Ncpus = max(1L, parallel::detectCores(logical = FALSE))
  )
}
