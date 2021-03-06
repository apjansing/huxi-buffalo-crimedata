library( ggplot2 )
library( dplyr )
library( maps)
library( ggmap )
library( mongolite )
library( lubridate )
library( gridExtra )
library( jsonlite )
library( shiny )
library( leaflet )

buf_cameras = mongo(collection = "cameras", db = "buffalo") # create connection, database and collection
buf_crimes = mongo(collection = "crimes", db = "buffalo") # create connection, database and collection

crime_types <- c( 'UUV',
                  'LARCENY/THEFT',
                  'BURGLARY',
                  'RAPE',
                  'SEXUAL ABUSE',
                  'ASSAULT',
                  'ROBBERY',
                  'THEFT OF SERVICES',
                  'MURDER',
                  'AGGR ASSAULT',
                  'CRIM NEGLIGENT HOMICIDE',
                  'AGG ASSAULT ON P/OFFICER',
                  'Theft of Vehicle',
                  'Sexual Assault',
                  'Theft',
                  'Breaking & Entering',
                  'Assault',
                  'MANSLAUGHTER',
                  'Other Sexual Offense')

# incident_id, case_number, incident_datetime, incident_type_primary, incident_description, clearance_type, address_1,
# address_2, city, state, zip, country, latitude, longitude, created_at, updated_at, location, hour_of_day,
# day_of_week, parent_incident_type, closestCamera
plotCrimes <- function( crimeCollection, options ){
  crimes <- ''
  
  limiter = '{'
  if( options$dateStart != options$dateEnd ){
    limiter = paste0(limiter, '"incident_datetime":{"$lte" : "',  format(options$dateEnd, format="%m/%d/%Y"), '", "$gte" : "', format(options$dateStart, format="%m/%d/%Y"),'"},')
  }
  
  
  if( options$crimez != '' ){
    limiter = paste0(limiter, '"incident_type_primary":{"$in" : [ ', options$crimez, ' ]},')
  }
  
  

  
  
  if(endsWith(limiter, ',')){
    limiter <- substr(limiter, start = 1, stop = nchar(limiter)-1 )
  }
  limiter <- paste0(limiter, '}')
  
  print(limiter)
  
  if(limiter == '{}') {
    crimes <- crimeCollection$find(limit = options$limit)
  } else {
    crimes <- crimeCollection$find(limiter, limit = options$limit)
  }

  buf_map <- leaflet() %>%
    addTiles('http://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png') %>%  # Add default OpenStreetMap map tiles
    addCircles( lng=crimes$longitude, lat=crimes$latitude, radius=5, 
                color="#ffa500", stroke = TRUE, fillOpacity = 0.5, popup=getDescription( crimes ))
  
  return(buf_map)
}

getDescription <- function( crime ){
  cityStateZip <- paste( sep = ' ', paste(sep = ', ', crime$city, crime$state), crime$zip )
  addr <- paste( sep = "<br/>", crime$address_1, crime$address_2, cityStateZip, crime$location )
  
  crimeDesc <- paste(sep = '<br/>', crime$parent_incident_type, crime$incident_type_primary, crime$incident_description, crime$incident_datetime)
  
  desc <- paste( sep = '<br/>', addr, '', crimeDesc)
  
  return(desc)
}

# Define UI for application that draws a histogram
ui <- fluidPage(
  
  # Application title
  titlePanel("Buffalo Crime Data"),
  
  # Sidebar with a slider input for number of bins 
  sidebarLayout(
    sidebarPanel(
      numericInput("limit", "Max number of results", 500, min = 1),
      selectInput( "crimes", "Choose a crimes:",
                   choices = crime_types, selected = crime_types, multiple = TRUE
      ),
      dateRangeInput("dateRange", "Date Range", format = 'mm/dd/yyyy', start = '01/01/2000')
    ),
    
    # Show a plot of the generated distribution
    mainPanel(
      leafletOutput("distPlot"), height = 500, width = 600
    )
  )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
  
  
  
  output$distPlot <- renderLeaflet({
    map
    
    # crimez <- paste(shQuote(input$crimes), collapse=", ")
    crimez <- paste0(sprintf("\"%s\"", input$crimes), collapse = ", ")

    d <- data.frame( dateStart = input$dateRange[1], dateEnd = input$dateRange[2], limit = input$limit, crimez = crimez )
    plotCrimes(crimeCollection = buf_crimes, options = d)
  })
}

# Run the application 
shinyApp(ui = ui, server = server)