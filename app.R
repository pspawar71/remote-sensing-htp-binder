# ============================================================
# REMOTE SENSING + GIS INTERACTIVE SHINY LECTURE
# 20 questions: 10 Remote Sensing + 10 GIS
# Local, session-specific data frame. No Google Sheets required.
# ============================================================

library(shiny)
library(shinyjs)
library(plotly)
library(terra)
library(leaflet)
library(leaflet.extras)
library(sf)
library(jsonlite)

# ------------------------- FILES ------------------------------
image_dir <- file.path(getwd(), "image")
paths <- c(
  rgb=file.path(image_dir,"rgb_image.tif"),
  ms=file.path(image_dir,"multispectral_image.tif"),
  hyper=file.path(image_dir,"hyper.tif"),
  wavelengths=file.path(image_dir,"wavelengths.csv"),
  field=file.path(getwd(),"field.geojson")
)
missing <- paths[!file.exists(paths)]
if(length(missing)) stop(paste("Missing required files:",paste(missing,collapse=", ")))

# ---------------- REMOTE-SENSING DATA -------------------------
rgb_image <- rast(paths[["rgb"]]); ms_image <- rast(paths[["ms"]]); hyper_image <- rast(paths[["hyper"]])
if(nlyr(rgb_image)<3) stop("rgb_image.tif requires at least three bands.")
if(nlyr(ms_image)<5) stop("multispectral_image.tif requires at least five bands.")
ms_bands <- c(Blue=1,Green=2,Red=3,RedEdge=4,NIR=5)
wavelength_table <- read.csv(paths[["wavelengths"]],stringsAsFactors=FALSE)
if(!"wavelength_nm"%in%names(wavelength_table)) stop("wavelengths.csv requires wavelength_nm.")
hyper_wavelengths <- as.numeric(wavelength_table$wavelength_nm)
if(length(hyper_wavelengths)!=nlyr(hyper_image)) stop("Wavelength count does not match hyperspectral bands.")
nearest_band <- function(target) which.min(abs(hyper_wavelengths-target))
hyper_rgb <- c(R=nearest_band(650),G=nearest_band(550),B=nearest_band(475))
hyper_targets <- c(Green=nearest_band(550),NIR=nearest_band(800))
spatial_resolution_cm <- c(RGB=1,Multispectral=2,Hyperspectral=25)
pixel_area_cm2 <- spatial_resolution_cm^2
band_choices <- c("Blue band"="Blue","Green band"="Green","Red band"="Red","Red-edge band"="RedEdge","Near-infrared band"="NIR")
true_assignment <- c(Red="Red",Green="Green",Blue="Blue")
false_assignment <- c(Red="NIR",Green="Red",Blue="Green")

# ------------------------- GIS DATA ---------------------------
field_raw <- st_read(paths[["field"]],quiet=TRUE,stringsAsFactors=FALSE)
needed <- c("plot_id","Canopy_Cov","NDVI")
if(length(setdiff(needed,names(field_raw)))) stop("field.geojson requires plot_id, Canopy_Cov, and NDVI.")
if(is.na(st_crs(field_raw))) st_crs(field_raw)<-32615
field_utm <- st_transform(st_make_valid(field_raw),32615)
field_utm$plot_id<-as.character(field_utm$plot_id); field_utm$Canopy_Cov<-as.numeric(field_utm$Canopy_Cov); field_utm$NDVI<-as.numeric(field_utm$NDVI)
field_map <- st_transform(field_utm,4326); field_bbox<-st_bbox(field_map)
query_flag <- is.finite(field_utm$Canopy_Cov)&is.finite(field_utm$NDVI)&field_utm$Canopy_Cov>80&field_utm$NDVI>0.772
query_count_expected <- sum(query_flag)
map_center <- c(lng=-96.3430,lat=30.6187); calculation_crs<-32614
make_rectangle <- function(xmin,ymin,xmax,ymax) st_polygon(list(matrix(c(xmin,ymin,xmax,ymin,xmax,ymax,xmin,ymax,xmin,ymin),ncol=2,byrow=TRUE)))
training_field <- st_sf(Name="Training field",geometry=st_sfc(make_rectangle(-96.3474,30.6162,-96.3387,30.6220),crs=4326))
target_area_ha <- as.numeric(st_area(st_transform(training_field,calculation_crs)))/10000

# ------------------------- QUESTIONS --------------------------
Q <- function(module,activity,question,type="MC",choices=NULL,values=NULL,correct=NULL,explanation="",image="NONE",tolerance=NA_real_) 
  list(module=module,activity=activity,question=question,type=type,choices=choices,values=values,correct=correct,explanation=explanation,image=image,tolerance=tolerance)
questions <- list(
 Q("Remote Sensing","Remote Sensing","Which activity uses remote sensing?","MC",c("Measuring stem diameter","Estimating canopy cover from a UAV RGB image","Weighing biomass","Measuring plant height"),c("A","B","C","D"),"B","UAV imaging collects information without touching plants."),
 Q("Remote Sensing","Active and Passive Sensing","Which statement is correct?","MC",c("Passive sensors detect naturally available energy","Active sensors detect only sunlight","Both types transmit energy","LiDAR is passive"),c("A","B","C","D"),"A","LiDAR and radar are active; optical cameras are commonly passive."),
 Q("Remote Sensing","Spectral Signature","What is a spectral signature?","MC",c("GPS position","Response across wavelengths","Plant height","Leaf count"),c("A","B","C","D"),"B","A spectral signature is a target response across wavelengths."),
 Q("Remote Sensing","Electromagnetic Spectrum","Which relationship is correct?","MC",c("Wavelength and energy are inversely related","They always increase together","All wavelengths have equal energy","Visible light is the entire spectrum"),c("A","B","C","D"),"A","Shorter wavelengths carry more photon energy."),
 Q("Remote Sensing","Vegetation Spectral Response","Why is healthy vegetation commonly brighter in NIR than red?","MC",c("Chlorophyll absorbs red while leaf structure reflects NIR","Vegetation absorbs all NIR","Only soil controls NIR","Red and NIR are identical"),c("A","B","C","D"),"A","Chlorophyll absorbs red and internal leaf structure scatters NIR."),
 Q("Remote Sensing","Spatial Resolution","Compare the images and select the finest spatial detail.","RS_SPATIAL",explanation="Smaller centimeters per pixel means finer detail."),
 Q("Remote Sensing","Color Composites","Create and save true-color and color-infrared composites.","RS_COMPOSITE",explanation="True color is RGB; color infrared is NIR/Red/Green."),
 Q("Remote Sensing","RGB Pixel Investigation","Click a vegetation pixel to calculate GLI.","RS_GLI",explanation="Positive GLI commonly indicates green vegetation.",image="RGB"),
 Q("Remote Sensing","Multispectral Pixel Investigation","Click a vegetation pixel to calculate NDVI.","RS_NDVI",explanation="Healthy vegetation commonly reflects more NIR and absorbs more red.",image="MS"),
 Q("Remote Sensing","Hyperspectral Signatures","Select vegetation and soil pixels to compare spectral signatures.","RS_HYPER",explanation="Vegetation and soil have different wavelength-dependent responses.",image="HYPER"),
 Q("GIS","GIS Concept","What is the primary purpose of GIS?","MC",c("Only attractive maps","Capture, manage, analyze, and visualize geographically referenced data","Only GPS coordinates","Only store images"),c("A","B","C","D"),"B","GIS connects locations with attributes for management and spatial analysis."),
 Q("GIS","Components of GIS","Which group represents the main components of GIS?","MC",c("Hardware, software, data, people, and methods","Maps and printers only","Raster and vector only","GPS and drones only"),c("A","B","C","D"),"A","GIS combines hardware, software, data, people, and methods."),
 Q("GIS","Vector Data","Which vector geometries represent sampling sites, roads, and field boundaries?","MC",c("Cells, bands, and pixels","Points, lines, and polygons","Tables, rows, and columns","Latitude only"),c("A","B","C","D"),"B","Vector data use points, lines, and polygons."),
 Q("GIS","Raster Data","How is geographic space represented in a raster dataset?","MC",c("Only polygons","Only GPS points","Text without locations","A regular grid of cells containing values"),c("A","B","C","D"),"D","Raster data represent geographic space as cells or pixels."),
 Q("GIS","Spatial Relationships","Which GIS operation identifies features that cross, touch, or fall within other features?","MC",c("Changing colors","Renaming a field","Spatial query and relationship analysis","Exporting a screenshot"),c("A","B","C","D"),"C","Intersects, within, and touches are GIS spatial relationships."),
 Q("GIS","Point Digitization","Digitize one sampling point inside the highlighted green field.","GIS_POINT",explanation="A sampling location is represented by point geometry."),
 Q("GIS","Polygon Digitization and Area","Trace the highlighted green field and submit its area in hectares.","GIS_AREA",explanation="Polygon geometry supports area calculation.",tolerance=.15),
 Q("GIS","Distance Calculation","Digitize exactly two sampling points and submit their distance in meters.","GIS_DISTANCE",explanation="GIS calculates distance from feature coordinates.",tolerance=.02),
 Q("GIS","Line Digitization","Digitize one route and submit its length in meters.","GIS_LINE",explanation="A route is represented by line geometry.",tolerance=.02),
 Q("GIS","Conditional Query","Highlight plots where Canopy_Cov > 80% and NDVI > 0.772, then submit the count.","GIS_QUERY",explanation="The query selects plots satisfying both attribute conditions.")
)

# ------------------------- HELPERS ----------------------------
`%||%` <- function(x,y) if(is.null(x)||length(x)==0||all(is.na(x))||identical(x,"")) y else x
clean_name <- function(x) gsub("\\s+"," ",trimws(x)); normalize_name<-function(x) gsub("\\s+","",tolower(trimws(x)))
request_id <- function() paste(format(Sys.time(),"%Y%m%d%H%M%OS6",tz="UTC"),Sys.getpid(),sample.int(1e9,1),sep="-")
safe_ratio <- function(a,b) if(!is.finite(b)||abs(b)<.Machine$double.eps) NA_real_ else a/b
feature_to_sf <- function(feature){if(is.null(feature)||is.null(feature$geometry))return(NULL);st_read(toJSON(list(type="FeatureCollection",features=list(feature)),auto_unbox=TRUE),quiet=TRUE)}
result_columns <- c("Time","Student","Module","Question_ID","Activity","Question","Answer","Correct","Clicked_X","Clicked_Y","Values","Expected")
empty_results <- function() as.data.frame(setNames(replicate(length(result_columns),character(0),simplify=FALSE),result_columns),stringsAsFactors=FALSE)

# ------------------------------ UI ----------------------------
ui <- fluidPage(useShinyjs(),tags$head(tags$meta(name="viewport",content="width=device-width, initial-scale=1"),tags$style(HTML("
body{background:linear-gradient(135deg,#eef5ff,#eefaf4);font-family:Inter,Arial;color:#1f2937}.shell{max-width:1200px;margin:auto;padding:22px}.card{background:white;border-radius:22px;padding:30px;margin-top:20px;box-shadow:0 15px 40px rgba(15,23,42,.1)}.title{font-size:36px;font-weight:800;color:#124c3c}.subtitle{color:#64748b;font-size:18px;margin-bottom:20px}.label{color:#0d6efd;font-size:13px;font-weight:800;letter-spacing:1px;text-transform:uppercase}.question{font-size:24px;font-weight:750;margin:12px 0 20px}.track{height:11px;border-radius:20px;background:#e2e8f0;overflow:hidden;margin:8px 0 20px}.fill{height:100%;background:linear-gradient(90deg,#0d6efd,#55c99a)}.box{background:#f8fafc;border:1px solid #dce3eb;border-radius:14px;padding:16px;margin:14px 0}.metric{background:white;border:1px solid #dce3eb;border-radius:12px;padding:13px;margin:8px 0}.buttons{display:flex;gap:12px;flex-wrap:wrap;margin-top:20px}.good{background:#ecfdf3;border-left:6px solid #198754;border-radius:12px;padding:16px;margin-top:20px}.bad{background:#fff1f2;border-left:6px solid #dc3545;border-radius:12px;padding:16px;margin-top:20px}.score{font-size:56px;color:#124c3c;font-weight:850}.leaflet-container{border-radius:12px}@media(max-width:700px){.shell{padding:8px}.card{padding:18px}.title{font-size:28px}.buttons .btn{width:100%}}
"))),div(class="shell",
 conditionalPanel("!output.started_screen && !output.finished_screen",div(class="card text-center",div(class="title","Remote Sensing and GIS for High-Throughput Phenotyping"),div(class="subtitle","Twenty guided questions: remote sensing concepts and imagery followed by GIS concepts and spatial activities."),div(style="max-width:520px;margin:20px auto;text-align:left",textInput("student_name","Student name",placeholder="Enter your full name")),actionButton("start","Start Combined Session",class="btn-primary btn-lg"))),
 conditionalPanel("output.started_screen",div(class="card",div(strong("Student: "),textOutput("student_display",inline=TRUE)),textOutput("progress_text"),div(class="track",uiOutput("progress_bar")),div(class="label",textOutput("module_activity",inline=TRUE)),div(class="question",textOutput("question")),
  conditionalPanel("output.is_mc",radioButtons("answer",NULL,choices=character(0),selected=character(0))),
  conditionalPanel("output.has_rs_image",div(class="box",plotOutput("rs_image",height="480px",click="rs_click"),uiOutput("rs_status"))),
  conditionalPanel("output.is_rs_spatial",div(class="box",selectInput("spatial_image","Image",c("RGB","Multispectral","Hyperspectral")),plotOutput("spatial_preview",height="380px"),uiOutput("spatial_cards"),selectInput("finest_image","Finest spatial detail",c("Select"="","RGB","Multispectral","Hyperspectral")))),
  conditionalPanel("output.is_rs_composite",div(class="box",selectInput("composite_type","Composite",c("True color"="TRUE","Color infrared"="FALSE")),fluidRow(column(4,selectInput("display_red","Red channel",band_choices,"Red")),column(4,selectInput("display_green","Green channel",band_choices,"Green")),column(4,selectInput("display_blue","Blue channel",band_choices,"Blue"))),plotOutput("composite_preview",height="420px"),actionButton("save_composite","Save Composite",class="btn-info"),uiOutput("composite_status"))),
  conditionalPanel("output.is_hyper",div(class="box",radioButtons("spectral_target","Target",c("Vegetation"="vegetation","Soil"="soil"),inline=TRUE),plotlyOutput("spectral_plot",height="400px"),uiOutput("spectral_values"))),
  conditionalPanel("output.has_gis_map",div(class="box",uiOutput("map_help"),leafletOutput("gis_map",height="550px"),uiOutput("map_status"))),
  conditionalPanel("output.is_area",numericInput("area_answer","Area (hectares)",NA,step=.001)),conditionalPanel("output.is_distance",numericInput("distance_answer","Distance (m)",NA,step=.01)),conditionalPanel("output.is_line",numericInput("line_answer","Line length (m)",NA,step=.01)),conditionalPanel("output.is_query",div(class="metric",actionButton("run_query","Run Query",class="btn-info"),numericInput("query_answer","Highlighted plot count",NA,min=0,step=1),uiOutput("query_status"))),
  div(class="buttons",actionButton("submit","Submit Answer",class="btn-primary btn-lg"),actionButton("next_question","Next Question",class="btn-success btn-lg"),downloadButton("download_results","Download Results",class="btn-info btn-lg")),uiOutput("feedback"))),
 conditionalPanel("output.finished_screen",div(class="card text-center",div(class="title","Combined Session Complete!"),div(class="subtitle","Student: ",textOutput("final_student",inline=TRUE)),div(class="score",textOutput("final_score",inline=TRUE)),div(class="subtitle",textOutput("final_percentage",inline=TRUE)),downloadButton("download_results_final","Download Results",class="btn-info btn-lg")))
))

# ---------------------------- SERVER --------------------------
server <- function(input,output,session){
 student<-reactiveVal(NULL);started<-reactiveVal(FALSE);finished<-reactiveVal(FALSE);qn<-reactiveVal(1);done<-reactiveVal(rep(FALSE,length(questions)));scores<-reactiveVal(rep(NA_integer_,length(questions)));feedback<-reactiveVal(NULL);results<-reactiveVal(empty_results())
 rs_x<-reactiveVal(NA_real_);rs_y<-reactiveVal(NA_real_);rgb_vals<-reactiveVal(NULL);ms_vals<-reactiveVal(NULL);expected_index<-reactiveVal(NA_real_);veg_spectrum<-reactiveVal(NULL);soil_spectrum<-reactiveVal(NULL);saved_true<-reactiveVal(NULL);saved_false<-reactiveVal(NULL)
 features<-reactiveVal(list());calc_area<-reactiveVal(NA_real_);calc_distance<-reactiveVal(NA_real_);calc_line<-reactiveVal(NA_real_);query_ran<-reactiveVal(FALSE)
 q<-reactive(questions[[qn()]]);type<-reactive(q()$type)
 output$started_screen<-reactive(started()&&!finished());output$finished_screen<-reactive(finished());output$is_mc<-reactive(type()=="MC");output$has_rs_image<-reactive(type()%in%c("RS_GLI","RS_NDVI","RS_HYPER"));output$is_rs_spatial<-reactive(type()=="RS_SPATIAL");output$is_rs_composite<-reactive(type()=="RS_COMPOSITE");output$is_hyper<-reactive(type()=="RS_HYPER");output$has_gis_map<-reactive(type()%in%c("GIS_POINT","GIS_AREA","GIS_DISTANCE","GIS_LINE","GIS_QUERY"));output$is_area<-reactive(type()=="GIS_AREA");output$is_distance<-reactive(type()=="GIS_DISTANCE");output$is_line<-reactive(type()=="GIS_LINE");output$is_query<-reactive(type()=="GIS_QUERY")
 for(id in c("started_screen","finished_screen","is_mc","has_rs_image","is_rs_spatial","is_rs_composite","is_hyper","has_gis_map","is_area","is_distance","is_line","is_query"))outputOptions(output,id,suspendWhenHidden=FALSE)
 output$student_display<-renderText(student());output$module_activity<-renderText(paste(q()$module,"|",q()$activity));output$question<-renderText(q()$question);output$progress_text<-renderText(paste("Question",qn(),"of",length(questions)));output$progress_bar<-renderUI(div(class="fill",style=paste0("width:",100*qn()/length(questions),"%")));output$feedback<-renderUI(feedback())
 reset_q<-function(){feedback(NULL);rs_x(NA_real_);rs_y(NA_real_);rgb_vals(NULL);ms_vals(NULL);expected_index(NA_real_);veg_spectrum(NULL);soil_spectrum(NULL);saved_true(NULL);saved_false(NULL);features(list());calc_area(NA_real_);calc_distance(NA_real_);calc_line(NA_real_);query_ran(FALSE);updateNumericInput(session,"area_answer",value=NA);updateNumericInput(session,"distance_answer",value=NA);updateNumericInput(session,"line_answer",value=NA);updateNumericInput(session,"query_answer",value=NA);shinyjs::enable("submit");shinyjs::disable("next_question")}

 output$rs_image<-renderPlot({if(type()=="RS_GLI")plotRGB(rgb_image,1,2,3,stretch="lin",axes=FALSE);if(type()=="RS_NDVI")plotRGB(ms_image,5,3,2,stretch="lin",axes=FALSE);if(type()=="RS_HYPER")plotRGB(hyper_image,hyper_rgb[["R"]],hyper_rgb[["G"]],hyper_rgb[["B"]],stretch="lin",axes=FALSE);if(is.finite(rs_x()))points(rs_x(),rs_y(),pch=21,bg="red",col="yellow",cex=2)},res=100)
 observeEvent(input$rs_click,{xy<-matrix(c(input$rs_click$x,input$rs_click$y),ncol=2);if(type()=="RS_GLI"){v<-as.numeric(extract(rgb_image,xy)[1,1:3]);rgb_vals(v);expected_index(safe_ratio(2*v[2]-v[1]-v[3],2*v[2]+v[1]+v[3]))};if(type()=="RS_NDVI"){v<-as.numeric(extract(ms_image,xy)[1,1:5]);ms_vals(v);expected_index(safe_ratio(v[5]-v[3],v[5]+v[3]))};if(type()=="RS_HYPER"){v<-as.numeric(extract(hyper_image,xy)[1,seq_len(nlyr(hyper_image))]);sp<-data.frame(Wavelength_nm=hyper_wavelengths,Reflectance=v);if(input$spectral_target=="vegetation"){veg_spectrum(sp);updateRadioButtons(session,"spectral_target",selected="soil")}else soil_spectrum(sp)};rs_x(input$rs_click$x);rs_y(input$rs_click$y)},ignoreInit=TRUE)
 output$rs_status<-renderUI({if(type()=="RS_GLI"){v<-rgb_vals();if(is.null(v))return(div(class="metric","Click vegetation."));div(class="metric",paste("R:",round(v[1],3),"G:",round(v[2],3),"B:",round(v[3],3),"GLI:",round(expected_index(),3)))}else if(type()=="RS_NDVI"){v<-ms_vals();if(is.null(v))return(div(class="metric","Click vegetation."));div(class="metric",paste("Red:",round(v[3],3),"NIR:",round(v[5],3),"NDVI:",round(expected_index(),3)))}else div(class="metric","Select vegetation and soil pixels.")})
 output$spectral_plot<-renderPlotly({validate(need(!is.null(veg_spectrum())||!is.null(soil_spectrum()),"Click a target."));p<-plot_ly();if(!is.null(veg_spectrum()))p<-add_trace(p,data=veg_spectrum(),x=~Wavelength_nm,y=~Reflectance,type="scatter",mode="lines",name="Vegetation");if(!is.null(soil_spectrum()))p<-add_trace(p,data=soil_spectrum(),x=~Wavelength_nm,y=~Reflectance,type="scatter",mode="lines",name="Soil");layout(p,xaxis=list(title="Wavelength (nm)"),yaxis=list(title="Reflectance"))})
 output$spectral_values<-renderUI(div(class="metric",paste("Vegetation:",if(is.null(veg_spectrum()))"not selected"else"selected","| Soil:",if(is.null(soil_spectrum()))"not selected"else"selected")))
 output$spatial_preview<-renderPlot({if(input$spatial_image=="RGB")plotRGB(rgb_image,1,2,3,stretch="lin",axes=FALSE);if(input$spatial_image=="Multispectral")plotRGB(ms_image,3,2,1,stretch="lin",axes=FALSE);if(input$spatial_image=="Hyperspectral")plotRGB(hyper_image,hyper_rgb[["R"]],hyper_rgb[["G"]],hyper_rgb[["B"]],stretch="lin",axes=FALSE)})
 output$spatial_cards<-renderUI(fluidRow(lapply(names(spatial_resolution_cm),function(n)column(4,div(class="metric",h4(n),p(paste(spatial_resolution_cm[[n]],"cm/pixel")),p(paste(pixel_area_cm2[[n]],"cm2/pixel")))))))
 output$composite_preview<-renderPlot({plotRGB(ms_image,r=ms_bands[[input$display_red]],g=ms_bands[[input$display_green]],b=ms_bands[[input$display_blue]],stretch="lin",axes=FALSE)})
 observeEvent(input$composite_type,{if(input$composite_type=="TRUE"){updateSelectInput(session,"display_red",selected="Red");updateSelectInput(session,"display_green",selected="Green");updateSelectInput(session,"display_blue",selected="Blue")}else{updateSelectInput(session,"display_red",selected="NIR");updateSelectInput(session,"display_green",selected="Red");updateSelectInput(session,"display_blue",selected="Green")}},ignoreInit=TRUE)
 observeEvent(input$save_composite,{a<-c(Red=input$display_red,Green=input$display_green,Blue=input$display_blue);if(input$composite_type=="TRUE"){saved_true(a);updateSelectInput(session,"composite_type",selected="FALSE")}else saved_false(a)},ignoreInit=TRUE)
 output$composite_status<-renderUI(div(class="metric",paste("True:",if(is.null(saved_true()))"not saved"else paste(saved_true(),collapse="/")),br(),paste("False:",if(is.null(saved_false()))"not saved"else paste(saved_false(),collapse="/"))))

 output$map_help<-renderUI(div(strong("Instructions: "),switch(type(),GIS_POINT="Place one marker inside the green field.",GIS_AREA="Trace the green field boundary.",GIS_DISTANCE="Place exactly two markers.",GIS_LINE="Draw one polyline.",GIS_QUERY="Run the fixed attribute query.","")))
 output$gis_map<-renderLeaflet({req(started(),output$has_gis_map());t<-type();if(t=="GIS_QUERY")return(leaflet()|>addProviderTiles(providers$Esri.WorldImagery)|>addPolygons(data=field_map,group="All plots",color="#64748b",weight=.35,fillColor="#8ecae6",fillOpacity=.25,popup=~paste0("Plot: ",plot_id,"<br>Canopy: ",round(Canopy_Cov,2),"<br>NDVI: ",round(NDVI,3)))|>fitBounds(field_bbox[["xmin"]],field_bbox[["ymin"]],field_bbox[["xmax"]],field_bbox[["ymax"]]));leaflet()|>addProviderTiles(providers$Esri.WorldImagery)|>setView(map_center[["lng"]],map_center[["lat"]],16)|>addPolygons(data=training_field,color="#00ff7f",weight=4,fillOpacity=.08)|>addDrawToolbar(targetGroup="drawn",polylineOptions=if(t=="GIS_LINE")drawPolylineOptions()else FALSE,circleOptions=FALSE,rectangleOptions=FALSE,circleMarkerOptions=FALSE,markerOptions=if(t%in%c("GIS_POINT","GIS_DISTANCE"))drawMarkerOptions()else FALSE,polygonOptions=if(t=="GIS_AREA")drawPolygonOptions(showArea=TRUE)else FALSE)})
 observeEvent(input$gis_map_draw_new_feature,{s<-tryCatch(feature_to_sf(input$gis_map_draw_new_feature),error=function(e)NULL);if(is.null(s))return();st_crs(s)<-4326;cur<-features();if(type()=="GIS_POINT"){cur<-list(s);leafletProxy("gis_map")|>clearGroup("drawn")|>addMarkers(data=s,group="drawn")};if(type()=="GIS_AREA"){cur<-list(s);a<-as.numeric(st_area(st_transform(s,calculation_crs)))/10000;calc_area(a);updateNumericInput(session,"area_answer",value=round(a,3))};if(type()=="GIS_DISTANCE"){cur<-c(cur,list(s));if(length(cur)>2)cur<-tail(cur,2);if(length(cur)==2){p<-do.call(rbind,cur)|>st_transform(calculation_crs);d<-as.numeric(st_distance(p[1,],p[2,]));calc_distance(d);updateNumericInput(session,"distance_answer",value=round(d,2))}};if(type()=="GIS_LINE"){cur<-list(s);m<-as.numeric(st_length(st_transform(s,calculation_crs)));calc_line(m);updateNumericInput(session,"line_answer",value=round(m,2))};features(cur)},ignoreInit=TRUE)
 output$map_status<-renderUI({if(type()=="GIS_POINT")div(class="metric",paste("Points:",length(features()),"/1"))else if(type()=="GIS_AREA")div(class="metric",paste("Area:",ifelse(is.finite(calc_area()),round(calc_area(),3),"not drawn"),"ha"))else if(type()=="GIS_DISTANCE")div(class="metric",paste("Points:",length(features()),"/2 | Distance:",ifelse(is.finite(calc_distance()),round(calc_distance(),2),"NA")))else if(type()=="GIS_LINE")div(class="metric",paste("Length:",ifelse(is.finite(calc_line()),round(calc_line(),2),"NA"),"m"))else NULL})
 observeEvent(input$run_query,{query_ran(TRUE);leafletProxy("gis_map")|>clearGroup("Query")|>addPolygons(data=field_map[query_flag,],group="Query",color="#ff006e",weight=2.5,fillColor="#ffbe0b",fillOpacity=.9)},ignoreInit=TRUE)
 output$query_status<-renderUI(if(query_ran())div(class="metric","Query completed. Count highlighted plots.")else"Query not run.")

 observeEvent(input$start,{nm<-clean_name(input$student_name%||%"");if(!nzchar(nm))return(showNotification("Enter your name.",type="warning"));student(nm);started(TRUE);finished(FALSE);qn(1);done(rep(FALSE,length(questions)));scores(rep(NA_integer_,length(questions)));results(empty_results());updateRadioButtons(session,"answer",choices=setNames(questions[[1]]$values,questions[[1]]$choices),selected=character(0));reset_q()})
 observeEvent(input$submit,{i<-qn();qq<-q();t<-type();if(done()[i])return();answer<-"";correct<-FALSE;expected<-"";vals<-""
  if(t=="MC"){if(is.null(input$answer)||!nzchar(input$answer))return(showNotification("Select an answer.",type="warning"));answer<-input$answer;correct<-identical(answer,qq$correct);expected<-qq$correct}
  if(t=="RS_SPATIAL"){if(!nzchar(input$finest_image))return(showNotification("Select the finest image.",type="warning"));answer<-input$finest_image;correct<-answer=="RGB";expected<-"RGB"}
  if(t=="RS_COMPOSITE"){if(is.null(saved_true())||is.null(saved_false()))return(showNotification("Save both composites.",type="warning"));answer<-paste(paste(saved_true(),collapse="/"),paste(saved_false(),collapse="/"),sep="; ");correct<-identical(unname(saved_true()),unname(true_assignment))&&identical(unname(saved_false()),unname(false_assignment));expected<-"RGB; NIR/Red/Green"}
  if(t%in%c("RS_GLI","RS_NDVI")){if(!is.finite(expected_index()))return(showNotification("Click a pixel.",type="warning"));answer<-round(expected_index(),3);correct<-TRUE;expected<-answer;vals<-if(t=="RS_GLI")paste(rgb_vals(),collapse="|")else paste(ms_vals(),collapse="|")}
  if(t=="RS_HYPER"){if(is.null(veg_spectrum())||is.null(soil_spectrum()))return(showNotification("Select vegetation and soil.",type="warning"));answer<-"Vegetation and soil spectra selected";correct<-TRUE;expected<-"Both selected"}
  if(t=="GIS_POINT"){if(length(features())!=1)return(showNotification("Digitize one point.",type="warning"));p<-st_transform(features()[[1]],calculation_crs);tf<-st_transform(training_field,calculation_crs);correct<-lengths(st_intersects(p,tf))[[1]]>0;answer<-"Digitized point";expected<-"Point inside green field"}
  if(t=="GIS_AREA"){if(length(features())!=1||!is.finite(input$area_answer))return(showNotification("Draw polygon and enter area.",type="warning"));answer<-input$area_answer;correct<-abs(input$area_answer-calc_area())<=max(.01,.02*calc_area())&&abs(calc_area()-target_area_ha)<=qq$tolerance*target_area_ha;expected<-round(target_area_ha,3)}
  if(t=="GIS_DISTANCE"){if(length(features())!=2||!is.finite(input$distance_answer))return(showNotification("Digitize two points.",type="warning"));answer<-input$distance_answer;correct<-abs(input$distance_answer-calc_distance())<=max(.5,qq$tolerance*calc_distance());expected<-round(calc_distance(),2)}
  if(t=="GIS_LINE"){if(length(features())!=1||!is.finite(input$line_answer))return(showNotification("Digitize one line.",type="warning"));answer<-input$line_answer;correct<-abs(input$line_answer-calc_line())<=max(.5,qq$tolerance*calc_line());expected<-round(calc_line(),2)}
  if(t=="GIS_QUERY"){if(!query_ran()||!is.finite(input$query_answer))return(showNotification("Run query and enter count.",type="warning"));answer<-input$query_answer;correct<-as.integer(answer)==query_count_expected;expected<-query_count_expected}
  row<-data.frame(Time=format(Sys.time(),"%Y-%m-%d %H:%M:%S",tz="UTC"),Student=student(),Module=qq$module,Question_ID=paste0("Q",i),Activity=qq$activity,Question=qq$question,Answer=as.character(answer),Correct=if(correct)"TRUE"else"FALSE",Clicked_X=ifelse(is.finite(rs_x()),rs_x(),NA),Clicked_Y=ifelse(is.finite(rs_y()),rs_y(),NA),Values=vals,Expected=as.character(expected),stringsAsFactors=FALSE)[result_columns];results(rbind(results(),row));d<-done();d[i]<-TRUE;done(d);s<-scores();s[i]<-if(correct)1L else 0L;scores(s);feedback(if(correct)div(class="good",h4("Correct!"),p(qq$explanation))else div(class="bad",h4("Incorrect"),p(paste("Expected:",expected)),p(qq$explanation)));shinyjs::disable("submit");shinyjs::enable("next_question")
 },ignoreInit=TRUE)
 observeEvent(input$next_question,{if(!done()[qn()])return();if(qn()>=length(questions)){started(FALSE);finished(TRUE);feedback(NULL);return()};qn(qn()+1);reset_q();if(type()=="MC")updateRadioButtons(session,"answer",choices=setNames(q()$values,q()$choices),selected=character(0))},ignoreInit=TRUE)
 output$final_student<-renderText(student());output$final_score<-renderText(paste0(sum(scores(),na.rm=TRUE)," / ",length(questions)));output$final_percentage<-renderText(paste0(round(100*sum(scores(),na.rm=TRUE)/length(questions),1),"%"))
 download_content<-function(file)write.csv(results(),file,row.names=FALSE,na="");output$download_results<-downloadHandler(filename=function()paste0("RS_GIS_results_",normalize_name(student()%||%"student"),".csv"),content=download_content);output$download_results_final<-downloadHandler(filename=function()paste0("RS_GIS_results_",normalize_name(student()%||%"student"),".csv"),content=download_content)
}
shinyApp(ui,server)
