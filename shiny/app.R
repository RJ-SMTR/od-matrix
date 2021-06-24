library(tidyverse)
library(shiny)
library(ggmap)
library(dplyr)
library(h3)
library(leaflet)

# This rdata file is 300MBs and cannot be synced to GitHub, I'll have to fix this. Hopefully with a SQL Query.
load("Onibus8Days.rdata")
load("CapacityData18June2021.rdata")

BusList <- distinct(Onibus8Days, ordem)
DateList <- distinct(Onibus8Days, data)
LineList <- distinct(Onibus8Days, linha)

# Define UI for application that draws a histogram
ui <- navbarPage("Onibus Data Exploration",
                 tabPanel("GPS Data",
                          # Sidebar with a slider input for number of bins 
                          sidebarLayout(
                              sidebarPanel(
                                  selectInput("BusNumber", label = h3("Bus Number"), 
                                              choices = BusList$ordem, 
                                              selected = 1),
                                  selectInput("Date", label = h3("Date"), 
                                              choices = DateList$data, 
                                              selected = 1),
                                  selectInput("Line", label = h3("Line"), 
                                              choices = LineList$linha, 
                                              selected = 1)
                              ),
                              # Show a plot of the generated distribution
                              mainPanel(
                                  plotOutput("mapPlot"),
                                  plotOutput("linePlot")
                              )
                          )
                 ),
                  tabPanel("h3 Data",
                           # Sidebar with a slider input for number of bins 
                           sidebarLayout(
                               sidebarPanel(
                                   selectInput("H3Date", label = h3("Date"), 
                                               choices = DateList$data, 
                                               selected = 1),
                                   sliderInput("HourSlider", label = h3("Time of Day"), min = 0, 
                                               max = 24, value = c(0, 24))
                               ),
                               # Show a plot of the generated distribution
                               mainPanel(
                                   leafletOutput("mymap", width = "100%", height = 800)
                               )
                           )
                 ),
                 tabPanel("Capacity Data",
                          # Sidebar with a slider input for number of bins 
                          sidebarLayout(
                              sidebarPanel(
                                  selectInput("CapacityDate", label = h3("Date"), 
                                              choices = DateList$data, 
                                              selected = 1),
                                  sliderInput("CapacityHourSlider", label = h3("Time of Day"), min = 0, 
                                              max = 24, value = c(0, 24)),
                                  selectInput("CapacityBusNumber", label = h3("Bus Number"), 
                                              choices = BusList$ordem, 
                                              selected = 1)
                                  #selectInput("Line", label = h3("Line"), 
                                  #            choices = LineList$linha, 
                                  #            selected = 1)
                              ),
                              # Show a plot of the generated distribution
                              mainPanel(
                                  leafletOutput("capacityMap", width = "100%", height = 800)
                              )
                          )
                 )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
    
    output$mapPlot <- renderPlot({
        qmplot(longitude, latitude, 
               data = Onibus8Days %>% dplyr::filter(ordem == input$BusNumber, data == input$Date), 
               maptype = "toner-lite", color = I("red"))
    })
    output$linePlot <- renderPlot({
        qmplot(longitude, latitude, 
               data = Onibus8Days %>% dplyr::filter(linha == input$Line, data == input$Date), 
               maptype = "toner-lite", color = I("red"))
    })

    output$mymap <- renderLeaflet({
        LeafletFilter <- Onibus8Days %>% filter(data == input$H3Date)
        
        h3_index <- geo_to_h3(c(LeafletFilter$latitude,LeafletFilter$longitude), res = 8)
        
        tbl <- table(h3_index) %>%
            tibble::as_tibble() %>%
            filter(n <= 60000)
        
        hexagons <- h3_to_geo_boundary_sf(tbl$h3_index) %>%
            dplyr::mutate(index = tbl$h3_index, DataPoints = tbl$n)
        
        pal <- colorBin(colorRamps::matlab.like2(10000), domain = hexagons$DataPoints, bins = 10000)
        
        leaflet(data = hexagons, width = "100%") %>%
            addProviderTiles("Stamen.Toner") %>%
            addPolygons(
                weight = 2,
                color = "white",
                fillColor = ~ pal(DataPoints),
                fillOpacity = 0.8,
                label = ~ sprintf("%i DataPoints (%s)", DataPoints, index)
            )
    })
    
    output$capacityMap <- renderLeaflet({
        FilteredCapacityData <- CapacityData %>% filter(data == '2021-06-11'
                                                #,timestamp_captura < ymd_hms("2021-06-09 14:00:00")
                                                #,timestamp_captura > ymd_hms("2021-06-09 13:00:00")
        )
        
        #h3_index <- geo_to_h3(c(FilteredCapacityData$latitude,FilteredCapacityData$longitude), res = 8)
        
        tbl <- FilteredCapacityData %>% group_by(TileID) %>%
            summarise(TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
            #filter(TotalCapacity < 40000) %>%
            tibble::as_tibble()
        
        hexagons <- h3_to_geo_boundary_sf(tbl$TileID) %>%
            dplyr::mutate(index = tbl$TileID, capacity = tbl$TotalCapacity)
        
        bins <- c(0, 100, 200, 500, 1000, 2000, 5000, 10000, Inf)
        pal <- colorBin("YlOrRd", domain = hexagons$capacity, bins = bins)
        
        leaflet(data = hexagons) %>%
            addProviderTiles("Stamen.Toner") %>%
            addPolygons(
            fillColor = ~pal(hexagons$capacity),
                weight = 2,
                opacity = 1,
                color = "white",
                dashArray = "3",
                fillOpacity = 1
                #label = ~ sprintf("%g DataPoints (%s)", Capacity, index)
            )
    })

}

# Run the application 
shinyApp(ui = ui, server = server)
