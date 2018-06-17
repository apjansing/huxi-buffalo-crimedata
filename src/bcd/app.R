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

# buf_coords <- c( lng = -78.8784 , lat = 42.8864 )   #42.8864° N, 78.8784° W
# content <- paste(sep = "<br/>",
#       "<b>The birthplace of R</b>",
#       buf_coords[1], buf_coords[2]
# )
# desc <- jsonlite::toJSON( c( 'Coordinates' = buf_coords, 'Descriptions' = "The birthplace of R"))
# buf_map <- leaflet() %>%
#   addTiles() %>%  # Add default OpenStreetMap map tiles
#   addMarkers(lng=buf_coords[1], lat=buf_coords[2], popup=content)

# getDescription <- function( queryResult ){
#   
# }

plotCrimes <- function( crimeCollection, options ){
  crimes <- ''
  if( options$dateStart != options$dateEnd ){
    limiter <- paste0('{"incident_datetime":{"$lte" : "',  format(options$dateEnd, format="%m/%d/%Y"), '", "$gte" : "', format(options$dateStart, format="%m/%d/%Y"),'"} }')
    print(limiter)
    crimes <- crimeCollection$find(limiter, limit = 500)
  }else {
    crimes <- crimeCollection$find()
  }
    
  
  # { "_id" : ObjectId("5b10af05ea49e74d62957cb2"), "incident_id" : 728765590, "case_number" : "15-2411024", 
  # "incident_datetime" : "08/29/2015 07:30:00 AM", "incident_type_primary" : "UUV", 
  # "incident_description" : "UUV", "clearance_type" : "", "address_1" : "VIRGINIA ST & MAIN ST", 
  # "address_2" : "", "city" : "BUFFALO", "state" : "NY", "zip" : "", "country" : "", 
  # "latitude" : 43.0064897171289, "longitude" : -78.880779986495, "created_at" : "08/30/2015 06:07:23 AM", 
  # "updated_at" : "09/05/2015 06:16:04 AM", "location" : "-78.880779986495,43.0064897171289", 
  # "hour_of_day" : 7, "day_of_week" : "Saturday", "parent_incident_type" : "Theft of Vehicle", "closestCamera" : 3.305976175310567 }
  
  buf_map <- leaflet() %>%
    addTiles('http://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png') %>%  # Add default OpenStreetMap map tiles
    addCircles( lng=crimes$longitude, lat=crimes$latitude, radius=5, 
                color="#ffa500", stroke = TRUE, fillOpacity = 0.5, popup=getDescription( crimes ))
  
  # map <- ggmap( city_map ) + geom_point( data = d, aes(x=lon, y=lat), col = "#a000ee", cex = .1 )
  # map <- plotCrimes( buf_crimes, buf_map )
  return(buf_map)
}

getDescription <- function( crime ){
  cityStateZip <- paste( sep = ' ', paste(sep = ', ', crime$city, crime$state), crime$zip )
  addr <- paste( sep = "<br/>", crime$address_1, crime$address_2, cityStateZip, crime$location )
  
  crimeDesc <- paste(sep = '<br/>', crime$parent_incident_type, crime$incident_type_primary, crime$incident_description, crime$incident_datetime)
  
  desc <- paste( sep = '<br/>', addr, '', crimeDesc)
  
  return(desc)
}

# map <- buf_map # plotCrimes(crimeCollection = buf_crimes, city_map = buf_map)

# Define UI for application that draws a histogram
ui <- fluidPage(
   
   # Application title
   titlePanel("Buffalo Crime Data"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
     sidebarPanel(
       sliderInput("bins",
                   "Number of bins:",
                   min = 1,
                   max = 50,
                   value = 30
                  ),
      selectInput( "Crimes", "Choose a crimes:",
        choices = c( 'UUV',
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
                     'Other Sexual Offense'
                    ), multiple = TRUE
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
     d <- data.frame( dateStart = input$dateRange[1], dateEnd = input$dateRange[2] )
     plotCrimes(crimeCollection = buf_crimes, options = d)
   })
}

# Run the application 
shinyApp(ui = ui, server = server)