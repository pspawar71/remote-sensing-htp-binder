# Remote Sensing and High-Throughput Phenotyping
# Interactive Shiny lecture with 10 questions
# Local in-memory results only. No Google Sheets or credentials required.

library(shiny)
library(shinyjs)
library(plotly)
library(terra)

# ============================================================
# CONFIGURATION
# ============================================================
course_id <- Sys.getenv("HTP_COURSE_ID", unset = "HTP_DEFAULT")

required_columns <- c(
  "Time", "Course_ID", "Student_ID", "Student", "Question_ID",
  "Activity", "Question", "Answer", "Correct", "Request_ID",
  "Submission_Key", "Clicked_X", "Clicked_Y", "Red_Value",
  "Green_Value", "Blue_Value", "NIR_Value", "Expected_Index"
)

empty_results <- function() {
  as.data.frame(
    setNames(
      replicate(length(required_columns), character(0), simplify = FALSE),
      required_columns
    ),
    stringsAsFactors = FALSE
  )
}

# ============================================================
# IMAGE DATA
# ============================================================
image_dir <- file.path(getwd(), "image")
paths <- c(
  rgb = file.path(image_dir, "rgb_image.tif"),
  ms = file.path(image_dir, "multispectral_image.tif"),
  hyper = file.path(image_dir, "hyper.tif"),
  wavelengths = file.path(image_dir, "wavelengths.csv")
)

missing_files <- paths[!file.exists(paths)]
if (length(missing_files) > 0) {
  stop(
    paste(
      "Missing required file(s):",
      paste(missing_files, collapse = ", ")
    )
  )
}

rgb_image <- rast(paths[["rgb"]])
ms_image <- rast(paths[["ms"]])
hyper_image <- rast(paths[["hyper"]])

if (nlyr(rgb_image) < 3) stop("rgb_image.tif must contain at least three bands.")
if (nlyr(ms_image) < 5) stop("multispectral_image.tif must contain at least five bands.")

rgb_bands <- c(Red = 1, Green = 2, Blue = 3)
ms_bands <- c(Blue = 1, Green = 2, Red = 3, RedEdge = 4, NIR = 5)

wavelength_table <- read.csv(paths[["wavelengths"]], stringsAsFactors = FALSE)
if (!"wavelength_nm" %in% names(wavelength_table)) {
  stop("wavelengths.csv must contain a wavelength_nm column.")
}

hyper_wavelengths <- as.numeric(wavelength_table$wavelength_nm)
if (length(hyper_wavelengths) != nlyr(hyper_image)) {
  stop("The wavelength count does not match the hyperspectral band count.")
}

nearest_band <- function(wavelengths, target) {
  which.min(abs(wavelengths - target))
}

hyper_rgb_bands <- c(
  Red = nearest_band(hyper_wavelengths, 650),
  Green = nearest_band(hyper_wavelengths, 550),
  Blue = nearest_band(hyper_wavelengths, 475)
)

target_wavelengths <- c(Green = 550, NIR = 800)
target_bands <- vapply(
  target_wavelengths,
  function(target) nearest_band(hyper_wavelengths, target),
  integer(1)
)
actual_target_wavelengths <- hyper_wavelengths[target_bands]
names(actual_target_wavelengths) <- names(target_wavelengths)

spatial_resolution_cm <- c(RGB = 1, Multispectral = 2, Hyperspectral = 25)
pixel_area_cm2 <- spatial_resolution_cm^2

band_choices <- c(
  "Blue band" = "Blue",
  "Green band" = "Green",
  "Red band" = "Red",
  "Red-edge band" = "RedEdge",
  "Near-infrared band" = "NIR"
)

true_assignment <- c(Red = "Red", Green = "Green", Blue = "Blue")
false_assignment <- c(Red = "NIR", Green = "Red", Blue = "Green")

# ============================================================
# QUESTIONS: EXACTLY 10
# ============================================================
questions <- list(
  list(
    activity = "Remote Sensing",
    question = "Which activity uses remote sensing?",
    choices = c(
      "Measuring stem diameter",
      "Estimating canopy cover from a UAV RGB image",
      "Weighing biomass",
      "Measuring plant height"
    ),
    values = c("A", "B", "C", "D"),
    correct = "B",
    explanation = "UAV imaging collects information without touching the plants."
  ),
  list(
    activity = "Active and Passive Sensing",
    question = "Which statement is correct?",
    choices = c(
      "Passive sensors detect naturally available energy",
      "Active sensors detect only sunlight",
      "Both types of sensors transmit energy",
      "LiDAR is passive"
    ),
    values = c("A", "B", "C", "D"),
    correct = "A",
    explanation = "LiDAR and radar are active, while optical cameras are commonly passive."
  ),
  list(
    activity = "Spectral Signature",
    question = "What is a spectral signature?",
    choices = c("GPS position", "Response across wavelengths", "Plant height", "Leaf count"),
    values = c("A", "B", "C", "D"),
    correct = "B",
    explanation = "A spectral signature describes wavelength-dependent reflectance or emission."
  ),
  list(
    activity = "Electromagnetic Spectrum",
    question = "Which relationship is correct?",
    choices = c(
      "Wavelength and energy are inversely related",
      "They always increase together",
      "All wavelengths have equal energy",
      "Visible light is the entire spectrum"
    ),
    values = c("A", "B", "C", "D"),
    correct = "A",
    explanation = "Wavelength and energy are inversely related, and shorter wavelengths carry more photon energy."
  ),
  list(
    activity = "Vegetation Spectral Response",
    question = "Why is healthy vegetation commonly brighter in NIR than in red?",
    choices = c(
      "Chlorophyll strongly absorbs red light, while internal leaf structure strongly reflects NIR",
      "Vegetation absorbs all NIR",
      "Only soil controls NIR",
      "Red and NIR are identical"
    ),
    values = c("A", "B", "C", "D"),
    correct = "A",
    explanation = "Chlorophyll absorbs red energy while internal leaf structure scatters NIR energy."
  ),
  list(
    activity = "Interactive Spatial Resolution",
    question = "Compare the three images and select the image with the finest spatial detail.",
    question_type = "SPATIAL_RESOLUTION",
    image_type = "NONE",
    explanation = "Smaller centimeters per pixel means finer spatial detail."
  ),
  list(
    activity = "Multispectral Color Composites",
    question = "Create and save a true-color composite and a color-infrared false-color composite.",
    question_type = "BAND_ASSIGNMENT",
    image_type = "NONE",
    explanation = "True color uses Red/Green/Blue. Color infrared uses NIR/Red/Green."
  ),
  list(
    activity = "RGB Pixel Investigation",
    question = "Click a vegetation pixel. The application will calculate the Green Leaf Index automatically.",
    question_type = "NUMERIC_GLI",
    image_type = "RGB",
    formula = "GLI = (2 x Green - Red - Blue) / (2 x Green + Red + Blue)",
    explanation = "Positive GLI values are generally associated with green vegetation."
  ),
  list(
    activity = "Multispectral Pixel Investigation",
    question = "Click a vegetation pixel. The application will calculate NDVI automatically.",
    question_type = "NUMERIC_NDVI",
    image_type = "MS",
    formula = "NDVI = (NIR - Red) / (NIR + Red)",
    explanation = "Healthy vegetation commonly reflects more NIR and absorbs more red energy."
  ),
  list(
    activity = "Hyperspectral Signatures",
    question = "Select vegetation and soil pixels to compare their spectral signatures.",
    question_type = "SPECTRAL_BANDS",
    image_type = "HYPER",
    explanation = "Vegetation and soil differ because of pigments, internal structure, moisture, and surface texture."
  )
)

questions <- lapply(questions, function(question) {
  if (is.null(question$question_type)) question$question_type <- "MULTIPLE_CHOICE"
  if (is.null(question$image_type)) question$image_type <- "NONE"
  if (is.null(question$formula)) question$formula <- ""
  question
})

initial_choices <- setNames(questions[[1]]$values, questions[[1]]$choices)

# ============================================================
# HELPERS
# ============================================================
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x)) || identical(x, "")) y else x
}

clean_name <- function(x) gsub("\\s+", " ", trimws(x))
normalize_name <- function(x) gsub("\\s+", "", tolower(trimws(x)))

new_request_id <- function() {
  paste(
    format(Sys.time(), "%Y%m%d%H%M%OS6", tz = "UTC"),
    Sys.getpid(),
    sample.int(1e9, 1),
    sep = "-"
  )
}

safe_ratio <- function(numerator, denominator) {
  if (!is.finite(denominator) || abs(denominator) < .Machine$double.eps) {
    return(NA_real_)
  }
  numerator / denominator
}

interpret_index <- function(index_name, value) {
  if (!is.finite(value)) return("No valid result is available.")

  if (index_name == "GLI") {
    if (value > 0.20) return("Strong green vegetation signal.")
    if (value > 0.00) return("Positive green vegetation signal.")
    return("Weak vegetation signal or a non-green target.")
  }

  if (index_name == "NDVI") {
    if (value >= 0.60) return("Strong vegetation response.")
    if (value >= 0.30) return("Moderate vegetation response.")
    if (value >= 0.10) return("Low vegetation response or sparse canopy.")
    return("Likely soil, residue, shadow, water, or another non-vegetation target.")
  }

  ""
}

# ============================================================
# USER INTERFACE
# ============================================================
ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$style(HTML("
      body { background: linear-gradient(135deg,#eef5ff,#f7fafc); font-family:Inter,Arial,sans-serif; color:#1f2937; }
      .app-shell { max-width:1100px; margin:auto; padding:24px; }
      .lecture-card { background:#fff; border-radius:22px; padding:34px; margin-top:22px; box-shadow:0 15px 40px rgba(15,23,42,.10); }
      .hero-title { font-size:38px; font-weight:800; color:#123b69; margin-bottom:8px; }
      .hero-subtitle { color:#64748b; font-size:18px; margin-bottom:24px; }
      .identity-box { max-width:500px; margin:25px auto; text-align:left; }
      .question-title { font-size:25px; line-height:1.42; font-weight:750; margin:12px 0 24px; }
      .activity-label { color:#0d6efd; font-size:13px; font-weight:800; letter-spacing:1px; text-transform:uppercase; }
      .progress-track { height:11px; border-radius:20px; background:#e2e8f0; overflow:hidden; margin:8px 0 24px; }
      .progress-fill { height:100%; background:linear-gradient(90deg,#198754,#4fd1a1); transition:width .25s ease; }
      .activity-box { background:#f5f9ff; border:1px solid #dbeafe; border-left:6px solid #0d6efd; border-radius:14px; padding:20px; margin:18px 0; }
      .image-box { background:#f8fafc; border:1px solid #dce3eb; border-radius:14px; padding:14px; margin:18px 0; }
      .metric-box { background:#fff; border:1px solid #dce3eb; border-radius:12px; padding:14px; margin:8px 0; }
      .button-row { display:flex; flex-wrap:wrap; gap:12px; margin-top:22px; }
      .feedback-correct { background:#ecfdf3; border-left:6px solid #198754; border-radius:12px; padding:18px; margin-top:22px; }
      .feedback-incorrect { background:#fff1f2; border-left:6px solid #dc3545; border-radius:12px; padding:18px; margin-top:22px; }
      .completion-badge { display:inline-block; background:#eaf7ef; color:#146c43; padding:8px 14px; border-radius:999px; font-weight:700; }
      .final-score { font-size:58px; color:#123b69; font-weight:850; margin:20px 0; }
      .index-result { margin-top:18px; padding:22px; border-radius:16px; color:#fff; background:linear-gradient(135deg,#146c43,#35a86b); text-align:center; }
      .index-name { font-size:15px; font-weight:750; letter-spacing:1px; text-transform:uppercase; }
      .index-value { margin:8px 0; font-size:46px; line-height:1; font-weight:850; }
      .selection-pending { padding:22px; margin-top:12px; border:2px dashed #cbd5e1; border-radius:16px; color:#64748b; background:#f8fafc; text-align:center; }
      .spatial-best { border:2px solid #198754; background:linear-gradient(180deg,#ffffff,#ecfdf3); }
      .spatial-value { margin:8px 0; font-size:28px; font-weight:850; color:#123b69; }
      .finest-badge { display:inline-block; margin-top:12px; padding:6px 11px; border-radius:999px; background:#198754; color:#fff; font-size:12px; font-weight:800; }
      @media(max-width:700px) { .app-shell { padding:10px; } .lecture-card { padding:20px; } .hero-title { font-size:29px; } .button-row .btn { width:100%; } }
    "))
  ),
  div(
    class = "app-shell",
    conditionalPanel(
      condition = "!output.started_screen && !output.finished_screen",
      div(
        class = "lecture-card text-center",
        div(class = "completion-badge", "Interactive learning module"),
        div(class = "hero-title", "Remote Sensing: Introduction and Basic Concepts"),
        div(class = "hero-subtitle", "Explore imagery, spectral behavior, color composites, indices, and spatial resolution."),
        div(class = "identity-box", textInput("student_name", "Student name", placeholder = "Enter your full name")),
        actionButton("start", "Start", class = "btn-primary btn-lg")
      )
    ),
    conditionalPanel(
      condition = "output.started_screen",
      div(
        class = "lecture-card",
        div(strong("Student: "), textOutput("student_display", inline = TRUE)),
        textOutput("progress_text"),
        div(class = "progress-track", uiOutput("progress_bar")),
        div(class = "activity-label", textOutput("activity", inline = TRUE)),
        div(class = "question-title", textOutput("question")),
        conditionalPanel(
          "output.question_has_image",
          div(
            class = "image-box",
            plotOutput("question_image", height = "480px", click = "image_click"),
            textOutput("image_caption")
          )
        ),
        conditionalPanel(
          "output.is_multiple_choice",
          radioButtons("answer", NULL, choices = initial_choices, selected = character(0))
        ),
        conditionalPanel(
          "output.is_spatial_question",
          div(
            class = "activity-box",
            h4("Compare spatial resolution"),
            selectInput("spatial_image", "Image to inspect", c("RGB", "Multispectral", "Hyperspectral")),
            div(class = "image-box", plotOutput("spatial_preview", height = "400px"), uiOutput("spatial_metadata")),
            uiOutput("automatic_spatial_results"),
            selectInput("finest_image", "Image with the finest spatial detail", c("Select" = "", "RGB", "Multispectral", "Hyperspectral"))
          )
        ),
        conditionalPanel(
          "output.is_composite_question",
          div(
            class = "activity-box",
            h4("Build multispectral composites"),
            selectInput("composite_type", "Composite", c("True color" = "TRUE_COLOR", "Color-infrared false color" = "FALSE_COLOR")),
            fluidRow(
              column(4, selectInput("display_red", "Red display channel", band_choices, "Red")),
              column(4, selectInput("display_green", "Green display channel", band_choices, "Green")),
              column(4, selectInput("display_blue", "Blue display channel", band_choices, "Blue"))
            ),
            div(class = "image-box", plotOutput("composite_preview", height = "430px")),
            actionButton("save_composite", "Save current composite", class = "btn-info"),
            uiOutput("composite_status")
          )
        ),
        conditionalPanel(
          "output.is_numeric_question",
          div(class = "activity-box", h4(textOutput("formula", inline = TRUE)), uiOutput("pixel_values"), uiOutput("automatic_index_result"))
        ),
        conditionalPanel(
          "output.is_spectral_question",
          div(
            class = "activity-box",
            radioButtons("spectral_target", "Target to select", c("Vegetation" = "vegetation", "Soil" = "soil"), inline = TRUE),
            plotlyOutput("spectral_plot", height = "440px"),
            uiOutput("spectral_status"),
            fluidRow(column(6, uiOutput("vegetation_reflectance_result")), column(6, uiOutput("soil_reflectance_result")))
          )
        ),
        div(
          class = "button-row",
          actionButton("submit", "Submit Answer", class = "btn-primary btn-lg"),
          actionButton("next_question", "Next Question", class = "btn-success btn-lg"),
          downloadButton("download_results", "Download My Results", class = "btn-info btn-lg")
        ),
        uiOutput("feedback")
      )
    ),
    conditionalPanel(
      condition = "output.finished_screen",
      div(
        class = "lecture-card text-center",
        div(class = "completion-badge", "Module completed"),
        div(class = "hero-title", "Session Complete!"),
        div(class = "hero-subtitle", "Thank you, ", textOutput("final_student", inline = TRUE), "!"),
        div(class = "final-score", textOutput("final_score", inline = TRUE)),
        downloadButton("download_results_final", "Download My Results", class = "btn-info btn-lg")
      )
    )
  )
)

# ============================================================
# SERVER
# ============================================================
server <- function(input, output, session) {
  student_name <- reactiveVal(NULL)
  started <- reactiveVal(FALSE)
  finished <- reactiveVal(FALSE)
  current_question <- reactiveVal(1)
  submitted <- reactiveVal(rep(FALSE, length(questions)))
  question_scores <- reactiveVal(rep(NA_integer_, length(questions)))
  feedback_ui <- reactiveVal(NULL)
  session_results <- reactiveVal(empty_results())

  clicked_x <- reactiveVal(NA_real_)
  clicked_y <- reactiveVal(NA_real_)
  red_value <- reactiveVal(NA_real_)
  green_value <- reactiveVal(NA_real_)
  blue_value <- reactiveVal(NA_real_)
  nir_value <- reactiveVal(NA_real_)
  expected_index <- reactiveVal(NA_real_)

  vegetation_spectrum <- reactiveVal(NULL)
  soil_spectrum <- reactiveVal(NULL)
  vegetation_expected <- reactiveVal(NULL)
  soil_expected <- reactiveVal(NULL)

  saved_true <- reactiveVal(NULL)
  saved_false <- reactiveVal(NULL)

  current_data <- reactive(questions[[current_question()]])

  append_local_result <- function(result_row) {
    current <- session_results()
    session_results(rbind(current, result_row))
    invisible(TRUE)
  }

  reset_activity <- function() {
    clicked_x(NA_real_); clicked_y(NA_real_)
    red_value(NA_real_); green_value(NA_real_); blue_value(NA_real_); nir_value(NA_real_)
    expected_index(NA_real_)
    vegetation_spectrum(NULL); soil_spectrum(NULL)
    vegetation_expected(NULL); soil_expected(NULL)
    saved_true(NULL); saved_false(NULL)
    updateSelectInput(session, "finest_image", selected = "")
    updateSelectInput(session, "spatial_image", selected = "RGB")
    updateSelectInput(session, "composite_type", selected = "TRUE_COLOR")
    updateSelectInput(session, "display_red", selected = "Red")
    updateSelectInput(session, "display_green", selected = "Green")
    updateSelectInput(session, "display_blue", selected = "Blue")
    updateRadioButtons(session, "spectral_target", selected = "vegetation")
  }

  output$started_screen <- reactive(started() && !finished())
  output$finished_screen <- reactive(finished())
  output$is_multiple_choice <- reactive(current_data()$question_type == "MULTIPLE_CHOICE")
  output$is_spatial_question <- reactive(current_data()$question_type == "SPATIAL_RESOLUTION")
  output$is_composite_question <- reactive(current_data()$question_type == "BAND_ASSIGNMENT")
  output$is_numeric_question <- reactive(current_data()$question_type %in% c("NUMERIC_GLI", "NUMERIC_NDVI"))
  output$is_spectral_question <- reactive(current_data()$question_type == "SPECTRAL_BANDS")
  output$question_has_image <- reactive(current_data()$image_type %in% c("RGB", "MS", "HYPER"))

  for (output_id in c(
    "started_screen", "finished_screen", "is_multiple_choice",
    "is_spatial_question", "is_composite_question", "is_numeric_question",
    "is_spectral_question", "question_has_image"
  )) outputOptions(output, output_id, suspendWhenHidden = FALSE)

  output$student_display <- renderText(student_name())
  output$activity <- renderText(current_data()$activity)
  output$question <- renderText(current_data()$question)
  output$progress_text <- renderText(paste("Question", current_question(), "of", length(questions)))
  output$progress_bar <- renderUI(div(class = "progress-fill", style = paste0("width:", current_question() / length(questions) * 100, "%")))
  output$formula <- renderText(current_data()$formula)
  output$feedback <- renderUI(feedback_ui())

  output$question_image <- renderPlot({
    image_type <- current_data()$image_type
    if (image_type == "RGB") plotRGB(rgb_image, r = 1, g = 2, b = 3, stretch = "lin", axes = FALSE)
    if (image_type == "MS") plotRGB(ms_image, r = 5, g = 3, b = 2, stretch = "lin", axes = FALSE)
    if (image_type == "HYPER") plotRGB(hyper_image, r = hyper_rgb_bands[["Red"]], g = hyper_rgb_bands[["Green"]], b = hyper_rgb_bands[["Blue"]], stretch = "lin", axes = FALSE)
    if (is.finite(clicked_x()) && is.finite(clicked_y())) points(clicked_x(), clicked_y(), pch = 21, bg = "red", col = "yellow", cex = 2)
  }, res = 100)

  output$image_caption <- renderText({
    switch(current_data()$image_type,
      RGB = "Click a green vegetation pixel.",
      MS = "Click a vegetation pixel.",
      HYPER = "Choose Vegetation or Soil, and then click the corresponding target.",
      ""
    )
  })

  observeEvent(input$image_click, {
    coordinates <- matrix(c(input$image_click$x, input$image_click$y), ncol = 2)
    question_type <- current_data()$question_type

    if (question_type == "NUMERIC_GLI") {
      values <- as.numeric(extract(rgb_image, coordinates)[1, 1:3])
      if (length(values) < 3 || any(!is.finite(values))) return(showNotification("No valid RGB data were found.", type = "error"))
      red_value(values[[1]]); green_value(values[[2]]); blue_value(values[[3]])
      expected_index(safe_ratio(2 * green_value() - red_value() - blue_value(), 2 * green_value() + red_value() + blue_value()))
    }

    if (question_type == "NUMERIC_NDVI") {
      values <- as.numeric(extract(ms_image, coordinates)[1, 1:5])
      if (length(values) < 5 || any(!is.finite(values[c(3, 5)]))) return(showNotification("No valid red and NIR data were found.", type = "error"))
      red_value(values[[3]]); nir_value(values[[5]])
      expected_index(safe_ratio(nir_value() - red_value(), nir_value() + red_value()))
    }

    if (question_type == "SPECTRAL_BANDS") {
      values <- as.numeric(extract(hyper_image, coordinates)[1, seq_len(nlyr(hyper_image))])
      if (length(values) != nlyr(hyper_image) || all(!is.finite(values))) return(showNotification("No valid hyperspectral data were found.", type = "error"))
      spectrum <- data.frame(Wavelength_nm = hyper_wavelengths, Reflectance = values)
      expected_values <- values[target_bands]
      names(expected_values) <- names(target_wavelengths)
      if (input$spectral_target == "vegetation") {
        vegetation_spectrum(spectrum); vegetation_expected(expected_values)
        updateRadioButtons(session, "spectral_target", selected = "soil")
        showNotification("Vegetation spectrum saved. Now click a soil pixel.")
      } else {
        soil_spectrum(spectrum); soil_expected(expected_values)
        showNotification("Soil spectrum saved. Review the results and submit.")
      }
    }

    clicked_x(input$image_click$x); clicked_y(input$image_click$y)
  }, ignoreInit = TRUE)

  output$pixel_values <- renderUI({
    if (!is.finite(clicked_x())) return(div(class = "metric-box", strong("Pixel selection: "), "No pixel selected."))
    if (current_data()$question_type == "NUMERIC_GLI") {
      return(div(class = "metric-box", h4("Extracted RGB values"),
        tags$p(tags$strong("Red: "), formatC(red_value(), format = "f", digits = 3)),
        tags$p(tags$strong("Green: "), formatC(green_value(), format = "f", digits = 3)),
        tags$p(tags$strong("Blue: "), formatC(blue_value(), format = "f", digits = 3))))
    }
    if (current_data()$question_type == "NUMERIC_NDVI") {
      return(div(class = "metric-box", h4("Extracted multispectral values"),
        tags$p(tags$strong("Red: "), formatC(red_value(), format = "f", digits = 3)),
        tags$p(tags$strong("NIR: "), formatC(nir_value(), format = "f", digits = 3))))
    }
  })

  output$automatic_index_result <- renderUI({
    question_type <- current_data()$question_type
    if (!question_type %in% c("NUMERIC_GLI", "NUMERIC_NDVI")) return(NULL)
    if (!is.finite(expected_index())) return(div(class = "selection-pending", h4("No result yet"), p("Click a vegetation pixel.")))
    index_name <- if (question_type == "NUMERIC_GLI") "GLI" else "NDVI"
    calculated_value <- round(expected_index(), 3)
    div(class = "index-result",
      div(class = "index-name", paste(index_name, "result")),
      div(class = "index-value", formatC(calculated_value, format = "f", digits = 3)),
      div(interpret_index(index_name, calculated_value)))
  })

  output$spatial_preview <- renderPlot({
    req(input$spatial_image)
    if (input$spatial_image == "RGB") plotRGB(rgb_image, r = 1, g = 2, b = 3, stretch = "lin", axes = FALSE)
    if (input$spatial_image == "Multispectral") plotRGB(ms_image, r = 3, g = 2, b = 1, stretch = "lin", axes = FALSE)
    if (input$spatial_image == "Hyperspectral") plotRGB(hyper_image, r = hyper_rgb_bands[["Red"]], g = hyper_rgb_bands[["Green"]], b = hyper_rgb_bands[["Blue"]], stretch = "lin", axes = FALSE)
  }, res = 100)

  output$spatial_metadata <- renderUI({
    req(input$spatial_image)
    raster <- switch(input$spatial_image, RGB = rgb_image, Multispectral = ms_image, Hyperspectral = hyper_image)
    div(class = "metric-box", paste("Rows:", nrow(raster), "| Columns:", ncol(raster), "| Bands:", nlyr(raster), "| Resolution:", spatial_resolution_cm[[input$spatial_image]], "cm/pixel"))
  })

  output$automatic_spatial_results <- renderUI({
    spatial_card <- function(image_name) {
      resolution <- unname(spatial_resolution_cm[[image_name]])
      area <- unname(pixel_area_cm2[[image_name]])
      is_finest <- resolution == min(spatial_resolution_cm)
      div(class = if (is_finest) "metric-box spatial-best" else "metric-box",
        h4(image_name),
        div(class = "spatial-value", paste0(resolution, " cm/pixel")),
        tags$p(tags$strong("Pixel ground area: "), paste0(area, " cm²")),
        if (is_finest) div(class = "finest-badge", "Smallest pixel size"))
    }
    fluidRow(column(4, spatial_card("RGB")), column(4, spatial_card("Multispectral")), column(4, spatial_card("Hyperspectral")))
  })

  output$composite_preview <- renderPlot({
    req(input$display_red, input$display_green, input$display_blue)
    plotRGB(ms_image,
      r = unname(ms_bands[[input$display_red]]),
      g = unname(ms_bands[[input$display_green]]),
      b = unname(ms_bands[[input$display_blue]]),
      stretch = "lin", axes = FALSE)
  }, res = 100)

  observeEvent(input$composite_type, {
    if (input$composite_type == "TRUE_COLOR") {
      updateSelectInput(session, "display_red", selected = "Red")
      updateSelectInput(session, "display_green", selected = "Green")
      updateSelectInput(session, "display_blue", selected = "Blue")
    } else {
      updateSelectInput(session, "display_red", selected = "NIR")
      updateSelectInput(session, "display_green", selected = "Red")
      updateSelectInput(session, "display_blue", selected = "Green")
    }
  }, ignoreInit = TRUE)

  observeEvent(input$save_composite, {
    assignment <- c(Red = input$display_red, Green = input$display_green, Blue = input$display_blue)
    if (input$composite_type == "TRUE_COLOR") {
      saved_true(assignment)
      updateSelectInput(session, "composite_type", selected = "FALSE_COLOR")
      showNotification("True-color composite saved. Now create false color.")
    } else {
      saved_false(assignment)
      showNotification("False-color composite saved. You can submit.")
    }
  }, ignoreInit = TRUE)

  output$composite_status <- renderUI({
    div(class = "metric-box",
      strong("True color: "), if (is.null(saved_true())) "Not saved" else paste(saved_true(), collapse = ", "), br(),
      strong("False color: "), if (is.null(saved_false())) "Not saved" else paste(saved_false(), collapse = ", "))
  })

  output$spectral_plot <- renderPlotly({
    validate(need(!is.null(vegetation_spectrum()) || !is.null(soil_spectrum()), "Click a target to create a spectral curve."))
    plot <- plot_ly()
    if (!is.null(vegetation_spectrum())) plot <- add_trace(plot, data = vegetation_spectrum(), x = ~Wavelength_nm, y = ~Reflectance, type = "scatter", mode = "lines", name = "Vegetation", line = list(color = "#198754", width = 3))
    if (!is.null(soil_spectrum())) plot <- add_trace(plot, data = soil_spectrum(), x = ~Wavelength_nm, y = ~Reflectance, type = "scatter", mode = "lines", name = "Soil", line = list(color = "#9a6b3f", width = 3))
    layout(plot, hovermode = "x unified", xaxis = list(title = "Wavelength (nm)"), yaxis = list(title = "Reflectance"))
  })

  output$spectral_status <- renderUI(div(class = "metric-box", paste("Selected bands:", paste(names(actual_target_wavelengths), round(actual_target_wavelengths, 2), "nm", collapse = " | "))))

  reflectance_card <- function(expected, label) {
    if (is.null(expected)) return(div(class = "selection-pending", h4(label), p(paste("Select", label, "and click a pixel."))))
    div(class = "metric-box", h4(label),
      tags$p(tags$strong("Green: "), formatC(expected[["Green"]], format = "f", digits = 4)),
      tags$p(tags$strong("NIR: "), formatC(expected[["NIR"]], format = "f", digits = 4)))
  }

  output$vegetation_reflectance_result <- renderUI(reflectance_card(vegetation_expected(), "Vegetation"))
  output$soil_reflectance_result <- renderUI(reflectance_card(soil_expected(), "Soil"))

  observeEvent(input$start, {
    entered_name <- clean_name(input$student_name %||% "")
    if (!nzchar(entered_name)) return(showNotification("Enter your name.", type = "warning"))
    student_name(entered_name)
    started(TRUE); finished(FALSE); current_question(1)
    submitted(rep(FALSE, length(questions)))
    question_scores(rep(NA_integer_, length(questions)))
    session_results(empty_results())
    reset_activity(); feedback_ui(NULL)
    updateRadioButtons(session, "answer", choices = initial_choices, selected = character(0))
    shinyjs::enable("submit"); shinyjs::disable("next_question")
  }, ignoreInit = TRUE)

  observeEvent(input$submit, {
    question_number <- current_question()
    question <- current_data()
    question_type <- question$question_type
    if (submitted()[question_number]) return()

    answer <- NULL
    correct <- FALSE

    if (question_type == "MULTIPLE_CHOICE") {
      answer <- input$answer
      if (is.null(answer) || !nzchar(answer)) return(showNotification("Select an answer.", type = "warning"))
      correct <- identical(answer, question$correct)
    }

    if (question_type %in% c("NUMERIC_GLI", "NUMERIC_NDVI")) {
      if (!is.finite(expected_index())) return(showNotification("Click a vegetation pixel before submitting.", type = "warning"))
      answer <- formatC(expected_index(), format = "f", digits = 3)
      correct <- TRUE
    }

    if (question_type == "SPATIAL_RESOLUTION") {
      if (is.null(input$finest_image) || !nzchar(input$finest_image)) return(showNotification("Select the image with the finest spatial detail.", type = "warning"))
      correct <- identical(input$finest_image, "RGB")
      answer <- paste0("Selected finest=", input$finest_image)
    }

    if (question_type == "BAND_ASSIGNMENT") {
      if (is.null(saved_true()) || is.null(saved_false())) return(showNotification("Save both composites first.", type = "warning"))
      correct <- identical(unname(saved_true()), unname(true_assignment)) && identical(unname(saved_false()), unname(false_assignment))
      answer <- paste(paste0("True color: ", paste(saved_true(), collapse = "/")), paste0("False color: ", paste(saved_false(), collapse = "/")), sep = "; ")
    }

    if (question_type == "SPECTRAL_BANDS") {
      if (is.null(vegetation_expected()) || is.null(soil_expected())) return(showNotification("Select vegetation and soil pixels before submitting.", type = "warning"))
      vegetation_result <- vegetation_expected(); soil_result <- soil_expected()
      answer <- paste(
        paste0("Vegetation Green=", formatC(vegetation_result[["Green"]], format = "f", digits = 4)),
        paste0("Vegetation NIR=", formatC(vegetation_result[["NIR"]], format = "f", digits = 4)),
        paste0("Soil Green=", formatC(soil_result[["Green"]], format = "f", digits = 4)),
        paste0("Soil NIR=", formatC(soil_result[["NIR"]], format = "f", digits = 4)),
        sep = "; "
      )
      correct <- TRUE
    }

    question_id <- paste0("Q", question_number)
    normalized_name <- normalize_name(student_name())
    result_row <- data.frame(
      Time = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      Course_ID = course_id,
      Student_ID = normalized_name,
      Student = student_name(),
      Question_ID = question_id,
      Activity = question$activity,
      Question = question$question,
      Answer = as.character(answer),
      Correct = if (correct) "TRUE" else "FALSE",
      Request_ID = new_request_id(),
      Submission_Key = paste(course_id, normalized_name, question_id, sep = "|"),
      Clicked_X = ifelse(is.finite(clicked_x()), clicked_x(), NA_real_),
      Clicked_Y = ifelse(is.finite(clicked_y()), clicked_y(), NA_real_),
      Red_Value = ifelse(is.finite(red_value()), red_value(), NA_real_),
      Green_Value = ifelse(is.finite(green_value()), green_value(), NA_real_),
      Blue_Value = ifelse(is.finite(blue_value()), blue_value(), NA_real_),
      NIR_Value = ifelse(is.finite(nir_value()), nir_value(), NA_real_),
      Expected_Index = ifelse(is.finite(expected_index()), expected_index(), NA_real_),
      stringsAsFactors = FALSE
    )[required_columns]

    append_local_result(result_row)

    status <- submitted(); status[question_number] <- TRUE; submitted(status)
    scores <- question_scores(); scores[question_number] <- if (correct) 1L else 0L; question_scores(scores)

    if (correct) {
      feedback_ui(div(class = "feedback-correct", h4("Submitted successfully"), p(question$explanation)))
    } else {
      correction <- if (question_type == "SPATIAL_RESOLUTION") {
        "RGB is the finest at 1 cm/pixel."
      } else if (question_type == "BAND_ASSIGNMENT") {
        "True color is Red/Green/Blue. False color is NIR/Red/Green."
      } else {
        paste("Correct answer:", question$correct)
      }
      feedback_ui(div(class = "feedback-incorrect", h4("Incorrect"), p(correction), p(question$explanation)))
    }

    shinyjs::disable("submit"); shinyjs::enable("next_question")
  }, ignoreInit = TRUE)

  observeEvent(input$next_question, {
    if (!submitted()[current_question()]) return()
    if (current_question() >= length(questions)) {
      finished(TRUE); started(FALSE); feedback_ui(NULL); return()
    }
    current_question(current_question() + 1)
    reset_activity(); feedback_ui(NULL)
    next_question <- current_data()
    if (next_question$question_type == "MULTIPLE_CHOICE") {
      updateRadioButtons(session, "answer", choices = setNames(next_question$values, next_question$choices), selected = character(0))
    }
    shinyjs::enable("submit"); shinyjs::disable("next_question")
  }, ignoreInit = TRUE)

  output$final_student <- renderText(student_name())
  output$final_score <- renderText(paste0(sum(question_scores(), na.rm = TRUE), " / ", length(questions)))

  download_results <- function(file) {
    write.csv(session_results(), file, row.names = FALSE, na = "")
  }

  output$download_results <- downloadHandler(
    filename = function() paste0("HTP_results_", normalize_name(student_name() %||% "student"), ".csv"),
    content = download_results
  )

  output$download_results_final <- downloadHandler(
    filename = function() paste0("HTP_results_", normalize_name(student_name() %||% "student"), ".csv"),
    content = download_results
  )
}

shinyApp(ui = ui, server = server)
