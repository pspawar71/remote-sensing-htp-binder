packages <- c("shiny","shinyjs","plotly","terra","leaflet","leaflet.extras","sf","jsonlite")
missing <- packages[!vapply(packages,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) install.packages(missing,repos="https://cloud.r-project.org",Ncpus=2)
