#
# This is the server logic of a Shiny web application. You can run the
#

library(shiny)

IntervalData <- read.csv("IntervalData.csv")
BRTOperators <- read.csv("BRTOperatorList.csv")

BRTLineList <- distinct(IntervalData, Line)
BRTOperatorList <- distinct(BRTOperators, Operator)

shinyServer(function(input, output) {
    
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
            filter(wday(AsAt) %in% input$DayOfWeekTable) %>%
            mutate(
                TotalCapacity = as.numeric(TotalCapacity),
                SittingCapacity = as.numeric(SittingCapacity)
            ) %>%
            group_by(Line) %>%
            summarise(   
                TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
                TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
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
                   SittingCapacity = TotalSittingCapacity, 
                   StandingCapacity = TotalStandingCapacity, 
                   TotalCapacity, UtilisationRate, Status = UtilisationStatus) %>%
            as_tibble() %>%
            datatable() %>%
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
                TotalCapacity = sum(TotalCapacity, na.rm = TRUE))
        
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
    
    # Spacial View -----------------------------------------------------------
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
})
