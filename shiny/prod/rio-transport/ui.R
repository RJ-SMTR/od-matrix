#
# This is the user-interface definition of a Shiny web application. You can
#

library(tidyverse)
library(shiny)
library(dplyr)
library(leaflet)
library(lubridate)
library(plotly)
library(hrbrthemes)
library(ggplot2)
library(viridis)
library(DT)
library(h3)
library(sf)
library(rmarkdown)
library(readxl)

IntervalData <- read.csv("IntervalData.csv")
BRTOperators <- read.csv("BRTOperatorList.csv")
onibus_utilisation <- read_csv("onibus_utilisation_v2.csv", col_types = cols(line = col_character())) 
origin_destination <- read_csv("vw_origin_destination_matrix.csv")
onibus_shapes  <- readxl::read_xlsx('onibus_shapes.xlsx') 

BRTLineList <- distinct(IntervalData, Line)
BRTOperatorList <- distinct(BRTOperators, Operator)
OnibusLineList <- distinct(onibus_utilisation, line)
OnibusIDList <- distinct(onibus_utilisation, onibus_id)
ODOriginTile <- distinct(origin_destination, origin_tile_id)

shinyUI(
    navbarPage(
      "Rio Transport Utilisation Analysis",
               # Documentation ------------------------------------------------------
               #tabPanel("Documentation",
               #           mainPanel(
               #             includeMarkdown("documentation.Rmd")
               #           )
               #         ),
               # OD Matrix ------------------------------------------------------
               tabPanel("Origin Destination Map",
                        sidebarLayout(
                          sidebarPanel(
                            sliderInput("ODHourSlider", label = h3("Time Interval"), min = 0, 
                                        max = 24, value = c(0, 24)),
                            helpText("Analyse the results during a particular time or period of the day."),
                            selectInput("OriginTile", label = h3("Origin Tile"), 
                                        choices = ODOriginTile$origin_tile_id,
                                        multiple = FALSE),
                            helpText("Instructions: Select a tile on the map to set as the origin. All destinations
                                     from that origin during the specified time window are then shown."),
                            width = 3
                          ),
                          mainPanel(
                            helpText("This is an Origin-Destination Matrix. Select a tile on the map to set as the origin. 
                                     All destinations from that origin during the specified time window are then shown."),
                            leafletOutput("ODMap", height = "650px")
                          )
                        )
               ),
               # Onibus Utilisation Map -----------------------------------------
               tabPanel("Onibus Utilisation",
                        sidebarLayout(
                          sidebarPanel(
                            selectInput("OnibusLine", label = h3("Line"), 
                                        choices = OnibusLineList$line,
                                        multiple = TRUE),
                            helpText("Analyse a particular line or multiple lines at once. 
                                     Once a line is selected, filter further by selecting a bus running on that line."),
                            conditionalPanel(
                              condition = "input.OnibusLine != ''",
                              selectInput("OnibusID", label = h3("Bus ID"), 
                                          choices = OnibusIDList$onibus_id,
                                          multiple = TRUE)),
                            sliderInput("OnibusUtilisationHourSlider", label = h3("Time Interval"), min = 0, 
                                        max = 24, value = c(0, 24)),
                            helpText("Analyse the results during a particular time or period of the day."),
                            numericInput("CashPayments", label = h3("Cash Payments"), value = 0.05, min = 0, max = 1, step = 0.05),
                            helpText("Cash Transactions: The proportion of all trips conducted in cash."),
                            numericInput("FareEvasion", label = h3("Fare Evasion"), value = 0.01, min = 0, max = 1, step = 0.05),
                            helpText("Fare Evasion: The proportion of all trips where the trip was evaded."),
                            numericInput("TileWeight", label = h3("Tile Opacity"), value = 0.8, min = 0, max = 1, step = 0.1),
                            helpText("Tile Opacity: Reduce the tile opacity to see the line map underneath."),
                            width = 3
                          ),
                          mainPanel(
                            leafletOutput("OnibusUtilisationMap", height = "650px"),
                            DT::dataTableOutput("OnibusTable")
                          )
                        )
               ),
               # BRT Heatmaps -----------------------------------------
               tabPanel("BRT Heatmaps",
                        sidebarLayout(
                            sidebarPanel(
                              selectInput("DayOfWeek", label = h3("Day of the Week"), 
                                          choices = 
                                              list("Monday" = 1, 
                                                   "Tuesday" = 2, 
                                                   "Wednesday" = 3,
                                                   "Thursday" = 4,
                                                   "Friday" = 5,
                                                   "Saturday" = 6,
                                                   "Sunday" = 7),
                                          selected = c(1, 2, 3, 4, 5, 6, 7),
                                          multiple = TRUE),
                                helpText("Focus your analyses on a particular day of the week or set of days."),
                                width = 3
                            ),
                            mainPanel(
                              helpText("This section contains another potential visualisation. For all BRT lines, the user can 
                                       analyse how utilisation and capacity changes throughout the day or set of days, as selected
                                       on the left panel. Note: The utilisation data is currently made up."),
                              helpText("Hover your mouse over the heatmap to see the rate at a particular point or click and drag
                                       over a section of the map to zoom in. Double click to zoom out."),
                              tags$h3("BRT Utilisation"),
                                plotlyOutput("UtilisationHeatmap", height = "600px"),
                              tags$h3("BRT Capacity"),
                                plotlyOutput("CapacityHeatmap" , height = "600px")
                            )
                        )
               ),
               # BRT Utilisation -------------------------------------------
               tabPanel("BRT Utilisation",
                        sidebarLayout(
                            sidebarPanel(
                              selectInput("DayOfWeekTable", label = h3("Day of the Week"), 
                                          choices = 
                                            list("Monday" = 1, 
                                                 "Tuesday" = 2, 
                                                 "Wednesday" = 3,
                                                 "Thursday" = 4,
                                                 "Friday" = 5,
                                                 "Saturday" = 6,
                                                 "Sunday" = 7),
                                          selected = c(1, 2, 3, 4, 5, 6, 7),
                                          multiple = TRUE),
                                helpText("Subset the results for a particular day of the week or set of days."),
                                sliderInput("TableHourSlider", label = h3("Time Interval"), min = 0, 
                                            max = 24, value = c(0, 24)),
                                helpText("Subset the results for a particular time or period of the day."),
                                width = 3
                            ),
                            mainPanel(
                              helpText("This section contains an earlier version of the 'Onibus Utilisation' section using BRT data.
                                       You can sort a particular column by selecting a column header or search for a particular
                                       line using the search box. Note: The utilisation data is currently made up."),
                              helpText("You can also select a line to see the location of that line's stops
                                       on the map below. Hover your mouse over the stops to see its name."),
                                DT::dataTableOutput("UtilisationTable"),
                                leafletOutput("SelectedLineMap")
                            )
                        )
               ),
               # BRT Line Details ---------------------------------------------
               tabPanel("BRT Line Details",
                        sidebarLayout(
                            sidebarPanel(
                                selectInput("ByLineLine", label = h3("Line"), 
                                            choices = BRTLineList$Line, 
                                            selected = 1),
                                helpText("Select the line you want to analyse here."),
                                selectInput("ByLineDayOfWeek", label = h3("Day of the Week"), 
                                            choices = 
                                              list("Monday" = 1, 
                                                   "Tuesday" = 2, 
                                                   "Wednesday" = 3,
                                                   "Thursday" = 4,
                                                   "Friday" = 5,
                                                   "Saturday" = 6,
                                                   "Sunday" = 7),
                                            selected = c(1, 2, 3, 4, 5, 6, 7),
                                            multiple = TRUE),
                                helpText("Focus your analyses on a particular day of the week or set of days."),
                                width = 3
                            ),
                            # Show a plot of the generated distribution
                            mainPanel(
                              helpText("Having used the 'BRT Heatmaps' and 'BRT Utilisation' sections to identify a 
                                       line that requires additional attention, this section is used to analyse a 
                                       particular line in detail. This section allows you to analyse stops along a 
                                       line throughout the day. Note: The utilisation data is currently made up."),
                                leafletOutput("LineMap"),
                              tags$h3("BRT Utilisation"),
                                plotlyOutput("LineUtilisationHeatmap", height = "600px"),
                              tags$h3("BRT Capacity"),
                                plotlyOutput("LineHeatmap", height = "600px")
                            )
                        )
               ),
               # Problem Identification Mock-up -----------------------------------------
               tabPanel("Problem Identification Mock-up",
                        helpText("This section contains a mockup of a potential solution that was presented to the team
                                 during the project."),
                        imageOutput("ProblemIdentification1", height = "650px"),
                        imageOutput("ProblemIdentification2", height = "650px"),
                        imageOutput("ProblemIdentification3", height = "650px"),
                        imageOutput("ProblemIdentification4", height = "650px")
               )
    )
)
