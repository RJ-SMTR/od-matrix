library(tidyverse)
library(shiny)
library(ggmap)
library(dplyr)
library(h3)
library(leaflet)
library(lubridate)
library(plotly)
library(hrbrthemes)
library(ggplot2)
library(viridis)

# This rdata file is 300MBs and cannot be synced to GitHub, I'll have to fix this. Hopefully with a SQL Query.
load("Onibus8Days.rdata")
load("CapacityData18June2021.rdata")
IntervalData <- read.csv("IntervalData.csv")
BRTOperators <- read.csv("BRTOperatorList.csv")

BusList <- distinct(Onibus8Days, ordem)
DateList <- distinct(Onibus8Days, data)
LineList <- distinct(Onibus8Days, linha)
BRTLineList <- distinct(IntervalData, Line)
BRTOperatorList <- distinct(BRTOperators, Operator)

# Define UI for application that draws a histogram
ui <- navbarPage("Data Exploration",
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
                 ),
                 tabPanel("Heatmaps",
                          sidebarLayout(
                              sidebarPanel(
                                  checkboxGroupInput("DayOfWeek", label = h3("Day of Week"), 
                                                     choices = list("Monday" = 1, 
                                                                    "Tuesday" = 2, 
                                                                    "Wednesday" = 3,
                                                                    "Thursday" = 4,
                                                                    "Friday" = 5,
                                                                    "Saturday" = 6,
                                                                    "Sunday" = 7),
                                                     selected = c(1, 2, 3, 4, 5, 6, 7)),
                                  width = 2
                              ),
                              # Show a plot of the generated distribution
                              mainPanel(
                                  plotlyOutput("UtilisationHeatmap"),
                                  plotlyOutput("CapacityHeatmap")

                              )
                          )
                 ),
                 tabPanel("By Line Data",
                          sidebarLayout(
                              sidebarPanel(
                                  selectInput("ByLineLine", label = h3("Line"), 
                                              choices = BRTLineList$Line, 
                                              selected = 1),
                                  checkboxGroupInput("ByLineDayOfWeek", label = h3("Day of Week"), 
                                                     choices = list("Monday" = 1, 
                                                                    "Tuesday" = 2, 
                                                                    "Wednesday" = 3,
                                                                    "Thursday" = 4,
                                                                    "Friday" = 5,
                                                                    "Saturday" = 6,
                                                                    "Sunday" = 7),
                                                     selected = c(1, 2, 3, 4, 5, 6, 7)),
                                  width = 2
                              ),
                              # Show a plot of the generated distribution
                              mainPanel(
                                  leafletOutput("LineMap"),
                                  plotlyOutput("LineUtilisationHeatmap"),
                                  plotlyOutput("LineHeatmap")
                                 
                              )
                          )
                 ),
                 tabPanel("Spacial View",
                          sidebarLayout(
                              sidebarPanel(
                                  checkboxGroupInput("SpacialViewOperator", label = h3("Operator"), 
                                              choices = BRTOperatorList$Operator, 
                                              selected = "Google"),
                                  checkboxGroupInput("SpacialViewDayOfWeek", label = h3("Day of Week"), 
                                                     choices = list("Monday" = 1, 
                                                                    "Tuesday" = 2, 
                                                                    "Wednesday" = 3,
                                                                    "Thursday" = 4,
                                                                    "Friday" = 5,
                                                                    "Saturday" = 6,
                                                                    "Sunday" = 7),
                                                     selected = c(1, 2, 3, 4, 5, 6, 7)),
                                  width = 2
                              ),
                              # Show a plot of the generated distribution
                              mainPanel(
                                  plotlyOutput("SpacialView", width = "100%", height = 600)
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
    
    output$CapacityHeatmap <- renderPlotly({
        
        # Interval data clean up input$DayOfWeek
        IntervalDataFiltered <- IntervalData %>%
            filter(wday(AsAt) %in% input$DayOfWeek) %>%
            mutate(
                TotalCapacity = as.numeric(TotalCapacity),
                SittingCapacity = as.numeric(SittingCapacity),
                Interval = ceiling_date(
                    as.POSIXct(EnterH3Time, format="%H:%M:%S"
                               #,tz="ET"
                               , origin = '1990-01-01'),
                    "30 mins")
            ) %>%
            group_by(Line, Interval) %>%
            summarise(   
                TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
                TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
                TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
            as_tibble() 
        
        p <- ggplot(IntervalDataFiltered, aes(x = Interval, Line, fill= TotalCapacity)) + 
            geom_tile() +
            scale_x_datetime(date_breaks = "2 hour",
                             date_labels = "%H:%M") + 
            scale_fill_gradient(low="white", high="blue") +
            theme_ipsum() +
            theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
            ggtitle("Total Capacity")
        
        ggplotly(p, tooltip=c("TotalCapacity", "TotalSittingCapacity"))
    })
    
    output$UtilisationHeatmap <- renderPlotly({
        # Interval data clean up input$DayOfWeek
        IntervalDataFiltered <- IntervalData %>%
            filter(wday(AsAt) %in% input$DayOfWeek) %>%
            mutate(
                TotalCapacity = as.numeric(TotalCapacity),
                SittingCapacity = as.numeric(SittingCapacity),
                Interval = ceiling_date(
                    as.POSIXct(EnterH3Time, format="%H:%M:%S"
                               #,tz="ET"
                               , origin = '1990-01-01'),
                    "30 mins")
            ) %>%
            group_by(Line, Interval) %>%
            summarise(   
                TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
                TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
                TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
            mutate(
                UtilisationRate = log(TotalCapacity) / 10
            ) %>%
        as_tibble() 
        
        p <- ggplot(IntervalDataFiltered, aes(x = Interval, Line, fill= UtilisationRate)) + 
            geom_tile() +
            scale_x_datetime(date_breaks = "2 hour",
                             date_labels = "%H:%M") + 
            scale_fill_gradient(low="white", high="red") +
            theme_ipsum() +
            theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
            ggtitle("Utilisation")
        
        ggplotly(p, tooltip=c("UtilisationRate"))
    })

    output$LineHeatmap <- renderPlotly({
        # Interval data clean up input$DayOfWeek
        IntervalDataFiltered <- IntervalData %>%
            filter(wday(AsAt) %in% input$ByLineDayOfWeek,
                   Line == input$ByLineLine) %>%
            mutate(
                TotalCapacity = as.numeric(TotalCapacity),
                SittingCapacity = as.numeric(SittingCapacity),
                Interval = ceiling_date(
                    as.POSIXct(EnterH3Time, format="%H:%M:%S"
                               #,tz="ET"
                               , origin = '1990-01-01'),
                    "30 mins")
            ) %>%
            group_by(Line, stop_name, stop_lat, stop_lon, stop_sequence, Interval) %>%
            summarise(   
                TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
                TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
                TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
            as_tibble() 
        
        p <- ggplot(IntervalDataFiltered, aes(x = Interval, stop_name, fill= TotalCapacity)) + 
            geom_tile() +
            scale_x_datetime(date_breaks = "2 hour",
                             date_labels = "%H:%M") + 
            scale_fill_gradient(low="white", high="blue") +
            theme_ipsum() +
            theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
            ggtitle("Line Capacity")
        
        ggplotly(p, tooltip=c("TotalCapacity", "TotalSittingCapacity"))
    })
    
    output$LineUtilisationHeatmap <- renderPlotly({
        # Interval data clean up input$DayOfWeek
        IntervalDataFiltered <- IntervalData %>%
            filter(wday(AsAt) %in% input$ByLineDayOfWeek,
                   Line == input$ByLineLine) %>%
            mutate(
                TotalCapacity = as.numeric(TotalCapacity),
                SittingCapacity = as.numeric(SittingCapacity),
                Interval = ceiling_date(
                    as.POSIXct(EnterH3Time, format="%H:%M:%S"
                               #,tz="ET"
                               , origin = '1990-01-01'),
                    "30 mins")
            ) %>%
            group_by(Line, stop_name, stop_lat, stop_lon, stop_sequence, Interval) %>%
            summarise(   
                TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
                TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
                TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
            mutate(
                Utilisation = jitter(log10(TotalCapacity) / 10)
            ) %>%
            as_tibble() 
        
        p <- ggplot(IntervalDataFiltered, aes(x = Interval, stop_name, fill= Utilisation)) + 
            geom_tile() +
            scale_x_datetime(date_breaks = "2 hour",
                             date_labels = "%H:%M") + 
            scale_fill_gradient(low="white", high="red") +
            theme_ipsum() +
            theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
            ggtitle("Utilisation")
        
        ggplotly(p, tooltip=c("Utilisation", "TotalSittingCapacity"))
    })
    
    output$LineMap <- renderLeaflet({
        IntervalDataFiltered <- IntervalData %>%
            filter(wday(AsAt) %in% input$ByLineDayOfWeek,
                   Line == input$ByLineLine) %>%
            mutate(
                TotalCapacity = as.numeric(TotalCapacity),
                SittingCapacity = as.numeric(SittingCapacity),
                Interval = ceiling_date(
                    as.POSIXct(EnterH3Time, format="%H:%M:%S"
                               #,tz="ET"
                               , origin = '1990-01-01'),
                    "30 mins")
            ) %>%
            group_by(Line, stop_name, stop_lat, stop_lon, stop_sequence, Interval) %>%
            summarise(   
                TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
                TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
                TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
            as_tibble() 
        
        leaflet(IntervalDataFiltered) %>% addTiles() %>%
            addMarkers(~stop_lon, ~stop_lat
                       ,label = ~paste0(stop_name, ", Total Capacity: ", round(TotalCapacity))
                       #,clusterOptions = ~stop_sequence
                       #,color = ~factpal(stop_sequence)
            )
    })
    
    output$SpacialView <- renderPlotly({
        IntervalDataFiltered <- IntervalData %>%
            left_join(BRTOperators) %>%
            filter(wday(AsAt) %in% input$SpacialViewDayOfWeek,
                   Operator == input$SpacialViewOperator) %>%
            mutate(
                TotalCapacity = as.numeric(TotalCapacity),
                SittingCapacity = as.numeric(SittingCapacity),
                Interval = ceiling_date(
                    as.POSIXct(EnterH3Time, format="%H:%M:%S"
                               #,tz="ET"
                               , origin = '1990-01-01'),
                    "30 mins")
            ) %>%
            group_by(Operator, Line, stop_name, stop_lat, stop_lon, stop_sequence, Interval) %>%
            summarise(   
                TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
                TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
                TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
            as_tibble() 
        
        p <- IntervalDataFiltered %>%
            mutate(text = paste0("Line: ", Line, ", Stop: ", stop_name, ", Total Capacity: ", TotalCapacity)) %>%
        ggplot( aes(x=stop_lon, y=stop_lat, size = TotalCapacity, color = Operator, text=text)) +
            geom_point(alpha=1) +
            scale_size(range = c(0.01, 4), name="Total Capacity") +
            scale_color_viridis(discrete=TRUE) +
            theme_ipsum() +
            theme(axis.title.x = element_blank(), axis.title.y = element_blank()) +
            scale_x_continuous(labels = NULL) + 
            scale_y_continuous(labels = NULL)
        
        ggplotly(p, tooltip="text")
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
