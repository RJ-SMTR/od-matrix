#
# This is the server logic of a Shiny web application. You can run the
#

library(shiny)

IntervalData <- read.csv("IntervalData.csv")
BRTOperators <- read.csv("BRTOperatorList.csv")
onibus_utilisation <- read_csv("onibus_utilisation_v2.csv", col_types = cols(line = col_character())) 
origin_destination <- read_csv("vw_origin_destination_matrix.csv")

BRTLineList <- distinct(IntervalData, Line)
BRTOperatorList <- distinct(BRTOperators, Operator)

shinyServer(function(input, output) {
    # OD Matrix ------------------------------------------------------------------
    output$ODMap <- renderLeaflet({
        ODBaseLayer <- distinct(origin_destination, origin_tile_id)
        
        ODBaseLayerHex <- h3_to_geo_boundary_sf(ODBaseLayer$origin_tile_id) %>%
            dplyr::mutate(
                index = ODBaseLayer$origin_tile_id
            ) 
        
        ODOriginTileHex <- h3_to_geo_boundary_sf(ODBaseLayer$origin_tile_id) %>%
            dplyr::mutate(
                index = ODBaseLayer$origin_tile_id
            ) %>%
            filter(
                index == input$OriginTile
            )
        
        #palOrigin <- colorBin(c("black"), domain = ODOriginTileHex$index)
        
        OriginDestinationFiltered <- origin_destination %>%
            filter(
                origin_hour >= input$ODHourSlider[1],
                origin_hour <= input$ODHourSlider[2]
            ) %>%
            filter(origin_tile_id == input$OriginTile) %>%
            group_by(origin_tile_id, destination_tile_id) %>%
            summarise(
                n = sum(n, na.rm = TRUE)
            ) 
        
        hexagons2 <- h3_to_geo_boundary_sf(OriginDestinationFiltered$destination_tile_id) %>%
            dplyr::mutate(
                index = OriginDestinationFiltered$destination_tile_id, 
                n = OriginDestinationFiltered$n
            )
        
        palOD <- colorBin("RdYlGn", domain = hexagons2$n, bins = 10
                         ,reverse = TRUE
                         )
        
        leaflet(data = hexagons2, width = "100%") %>%
            addProviderTiles("Stamen.Toner")  %>%
            addPolygons(
                weight = 2,
                color = "white",
                fillColor = ~ palOD(n),
                fillOpacity = 1,
                label = ~ sprintf("%*.f Destinations", 4, n)
            ) %>%
            addPolygons(
                weight = 2,
                color = "white",
                layerId = ~index,
                data = ODBaseLayerHex
            )%>%
            addPolygons(
                weight = 5,
                color = "yellow",
                data = ODOriginTileHex,
                fillColor = "black",
                fillOpacity = 1
            ) %>%
            addLegend("topright", pal = palOD, values = ~n,
                      title = " ",
                      #labFormat = labelFormat(prefix = "$"),
                      opacity = 1
            )
        
    })
    
    observe({
        ## the sgmap2 needs to match the name of the map you're outputting above
        event <- input$ODMap_shape_click
        print( event )
        updateSelectInput(session = getDefaultReactiveDomain(), inputId = "OriginTile", selected = event$id)
        
    }) 
    
    # Onibus Utilisation Map -----------------------------------------------------
    OnibusUtilisationReactive <- reactive({
        if(!is.null(input$OnibusLine)){ # If line selected, filter line and update bus ID filter
            onibus_utilisation %>% filter(line %in% input$OnibusLine)
        }
        else {onibus_utilisation}
    })  
    
    observe({
        if(!is.null(input$OnibusLine)){
            updateSelectInput(
                session = getDefaultReactiveDomain(),
                inputId = "OnibusID",
                choices = distinct(OnibusUtilisationReactive(), onibus_id)
            )}
    })
    
    OnibusUtilisationReactiveOnibusID <- reactive({
        if(!is.null(input$OnibusID)){
            OnibusUtilisationReactive() %>% filter(onibus_id %in% input$OnibusID)
        } 
        else{OnibusUtilisationReactive()}
    })
    
    output$OnibusUtilisationMap <- renderLeaflet({
        utilisation_map <- OnibusUtilisationReactiveOnibusID() %>%
            mutate(h3_time_enter = hour(as.POSIXct(h3_time_enter, format="%H:%M:%S"
                                                   , origin = '1990-01-01')),
                   n_passengers_adjusted = n_passengers_adjusted / (1 - (input$CashPayments + input$FareEvasion) ),
                   utilisation_total_adjusted = n_passengers_adjusted / average_capacity_total
                   ) %>%
            filter(
                h3_time_enter >= input$OnibusUtilisationHourSlider[1],
                h3_time_enter <= input$OnibusUtilisationHourSlider[2]
                #,utilisation_total_adjusted <= 2
            ) %>%
            group_by(tile_id) %>%
            summarise(
                demand = mean(n_passengers_adjusted, na.rm = TRUE),
                sitting_supply = mean(average_capacity_total, na.rm = TRUE),
                utilisation_total_adjusted = mean(utilisation_total_adjusted, na.rm = TRUE)
            ) 
        
        hexagons <- h3_to_geo_boundary_sf(utilisation_map$tile_id) %>%
            dplyr::mutate(
                index = utilisation_map$tile_id, 
                utilisation = utilisation_map$utilisation_total_adjusted,
                demand = utilisation_map$demand,
                sitting_supply = utilisation_map$sitting_supply
            )
        
        pal <- colorBin("RdYlGn", domain = c(0, 1), reverse = TRUE)
        
        leaflet(data = hexagons, width = "100%") %>%
            addProviderTiles("Stamen.Toner") %>%
            addPolygons(
                weight = 2,
                color = "white",
                fillColor = ~ pal(utilisation),
                fillOpacity = 0.8,
                label = ~ sprintf("%*.f Perc. Average Utilisation", 4, utilisation * 100),
                layerId = ~index
            ) %>%
        addLegend("topright", pal = pal, values = ~utilisation,
                          opacity = 1
            )
    })
    
    OnibusUtilisationFiltered <- reactive({
        if(!is.null(input$OnibusLine)){ # If line selected, filter line and update bus ID filter
            onibus_utilisation %>% filter(line %in% input$OnibusLine)
        }
        else {onibus_utilisation}
    })  
    
    output$OnibusTable <- DT::renderDataTable({
        OnibusUtilisationFiltered <- OnibusUtilisationFiltered() %>%
            mutate(EnterH3Hour = hour(as.POSIXct(h3_time_enter, format="%H:%M:%S"
                                                 , origin = '1990-01-01')),
                   Interval = ceiling_date(as.POSIXct(h3_time_enter, format="%H:%M:%S"
                                                      , origin = '1990-01-01'), "1 hour"),
                   n_passengers_adjusted = n_passengers_adjusted / (1 - (input$CashPayments + input$FareEvasion)),
                   utilisation_total_adjusted = n_passengers_adjusted / average_capacity_total
            ) %>%
            filter(
                EnterH3Hour >= input$OnibusUtilisationHourSlider[1],
                EnterH3Hour <= input$OnibusUtilisationHourSlider[2]
            ) %>%
            group_by(line, Interval) %>%
            summarise(   
                Busses = n_distinct(onibus_id),
                AveragePassengers = mean(n_passengers_adjusted, na.rm = TRUE) %>% round(digits = 0),
                AverageCapacity = mean(average_capacity_total, na.rm = TRUE) %>% round(digits = 0),
                AverageUtilisation = mean(utilisation_total_adjusted, na.rm = TRUE) %>% round(digits = 2)
            ) %>%
            mutate(
                Interval = hour(Interval),
                UtilisationStatus = case_when(
                    AverageUtilisation >= 0.8 ~ "Unacceptably High",
                    between(AverageUtilisation, 0.4, 0.8) ~ "Acceptable",
                    AverageUtilisation < 0.4 ~ "Unacceptably Low",
                    TRUE ~ "Error"
                )
            ) %>%
            as_tibble() %>%
            datatable(
                options = list(pageLength = 20)
            ) %>%
            formatStyle('UtilisationStatus', 
                        backgroundColor = styleEqual(c("Unacceptably High", "Unacceptably Low", "Acceptable"), c('orange', 'yellow', 'light blue'))
            ) %>%
            formatStyle('AverageUtilisation',
                        background = styleColorBar(range(0, 2), 'lightblue'),
                        backgroundSize = '98% 88%',
                        backgroundRepeat = 'no-repeat',
                        backgroundPosition = 'center')
        
    }, server = FALSE)
    
    # Capacity Heatmap -----------------------------------------------------
    output$CapacityHeatmap <- renderPlotly({
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
    
    # Utilisation heatmap -----------------------------------------------------
    output$UtilisationHeatmap <- renderPlotly({
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
    
    # Utilisation Table ----------------------------------------------------
    output$UtilisationTable <- DT::renderDataTable({
        
        IntervalDataFiltered <- IntervalData %>%
            mutate(EnterH3Hour = hour(as.POSIXct(EnterH3Time, format="%H:%M:%S"
                                            , origin = '1990-01-01'))) %>%
            filter(wday(AsAt) %in% input$DayOfWeekTable,
                   EnterH3Hour >= input$TableHourSlider[1],
                   EnterH3Hour <= input$TableHourSlider[2]
                   ) %>%
            group_by(Line) %>%
            summarise(   
                TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
            mutate(
                UtilisationRate = log(TotalCapacity) / 10 - 0.7,
                UtilisationRate = round(UtilisationRate, 2),
                UtilisationStatus = case_when(
                    UtilisationRate >= 0.8 ~ "Unacceptably High",
                    between(UtilisationRate, 0.4, 0.8) ~ "Acceptable",
                    UtilisationRate < 0.4 ~ "Unacceptably Low",
                    TRUE ~ "Error"
                )
            ) %>%
            left_join(BRTOperators) %>%
            select(Line, Operator, 
                   TotalCapacity, UtilisationRate, Status = UtilisationStatus) %>%
            add_column(Buses = round(runif(nrow(.)) * 10, digits = 0)) %>%
            relocate(Buses, .before = TotalCapacity) %>%
            as_tibble() %>%
            datatable(selection = list(mode = 'single', selected = c(1))) %>%
            formatStyle('Status', 
                        backgroundColor = styleEqual(c("Unacceptably High", "Unacceptably Low", "Acceptable"), c('orange', 'yellow', 'light blue'))
            ) %>%
            formatStyle('UtilisationRate',
                        background = styleColorBar(range(0, 2), 'lightblue'),
                        backgroundSize = '98% 88%',
                        backgroundRepeat = 'no-repeat',
                        backgroundPosition = 'center')
    }, server = FALSE)
    
    # Selected Line Map -------------------------------------------------------
    output$SelectedLineMap <- renderLeaflet({
        IntervalDataFiltered <- IntervalData %>%
            filter(wday(AsAt) %in% input$DayOfWeekTable) %>%
            mutate(
                TotalCapacity = as.numeric(TotalCapacity),
                SittingCapacity = as.numeric(SittingCapacity)
            ) %>%
            group_by(Line) %>%
            summarise(   
                TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
                TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
                TotalCapacity = sum(TotalCapacity, na.rm = TRUE)
                ) 
        
        s <- input$UtilisationTable_rows_selected
        line <- IntervalDataFiltered[s, ]
        
        IntervalDataMap <- IntervalData %>%
            filter(Line == line$Line) %>%
            dplyr::distinct(Line, stop_name, stop_lat, stop_lon) %>%
            as_tibble() 
        
        leaflet(IntervalDataMap) %>% addTiles() %>%
            addMarkers(~stop_lon, ~stop_lat
                       ,label = ~paste0(stop_name)
            )
    })
    
    # Line Heatmap ------------------------------------------------------------
    output$LineHeatmap <- renderPlotly({
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
    
    # Line Utilisation Heatmap -----------------------------------------------
    output$LineUtilisationHeatmap <- renderPlotly({
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
    
    # Line Map -------------------------------------------------------------
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
    
    # Problem Identification Mockups ---------------------------------------
    output$ProblemIdentification1 <- renderImage({
        list(src = './images/ProblemIdentification1.png', width = "60%")
    }, deleteFile = FALSE)
    
    output$ProblemIdentification2 <- renderImage({
        list(src = './images/ProblemIdentification2.png', width = "60%")
    }, deleteFile = FALSE)
    
    output$ProblemIdentification3 <- renderImage({
        list(src = './images/ProblemIdentification3.png', width = "60%")
    }, deleteFile = FALSE)
    
    output$ProblemIdentification4 <- renderImage({
        list(src = './images/ProblemIdentification4.png', width = "60%")
    }, deleteFile = FALSE)

})
