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

IntervalData <- read.csv("IntervalData.csv")
BRTOperators <- read.csv("BRTOperatorList.csv")
onibus_utilisation <- read_csv("onibus_utilisation.csv", col_types = cols(line = col_character())) 
origin_destination <- read_csv("origin_destination_map.csv")

BRTLineList <- distinct(IntervalData, Line)
BRTOperatorList <- distinct(BRTOperators, Operator)
OnibusLineList <- distinct(onibus_utilisation, line)
OnibusIDList <- distinct(onibus_utilisation, onibus_id)
ODOriginTile <- distinct(origin_destination, origin_tile_id)

shinyUI(
    navbarPage("Rio Transport: Prod",
               # Homepage -----------------------------------------
               tabPanel("Homepage",
                                imageOutput("HomepageMockup")
               ),
               # OD Matrix ------------------------------------------------------
               tabPanel("OD Matrix",
                        sidebarLayout(
                          sidebarPanel(
                            sliderInput("ODHourSlider", label = h3("Time of Day"), min = 0, 
                                        max = 24, value = c(0, 24)),
                            selectInput("OriginTile", label = h3("Origin Tile"), 
                                        choices = ODOriginTile$origin_tile_id,
                                        multiple = FALSE)
                          ),
                          mainPanel(
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
                            conditionalPanel(
                              condition = "input.OnibusLine != ''",
                              selectInput("OnibusID", label = h3("Bus ID"), 
                                          choices = OnibusIDList$onibus_id,
                                          multiple = TRUE)),
                            sliderInput("OnibusUtilisationHourSlider", label = h3("Time of Day"), min = 0, 
                                        max = 24, value = c(0, 24))
                          ),
                          mainPanel(
                            leafletOutput("OnibusUtilisationMap", height = "650px"),
                            DT::dataTableOutput("OnibusTable")
                          )
                        )
               ),
               # Mockup: Problem Identification -----------------------------------------
               tabPanel("Mockup: Problem Identification",
                        imageOutput("ProblemIdentification1", height = "650px"),
                        imageOutput("ProblemIdentification2", height = "650px"),
                        imageOutput("ProblemIdentification3", height = "650px"),
                        imageOutput("ProblemIdentification4", height = "650px")
               ),
               # Summary: Heatmaps -----------------------------------------
               tabPanel("Summary: Heatmaps",
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
                            mainPanel(
                                plotlyOutput("UtilisationHeatmap"),
                                plotlyOutput("CapacityHeatmap")
                            )
                        )
               ),
               # Summary: Tables -------------------------------------------
               tabPanel("Summary: Table",
                        sidebarLayout(
                            sidebarPanel(
                                checkboxGroupInput("DayOfWeekTable", label = h3("Day of Week"), 
                                                   choices = list("Monday" = 1, 
                                                                  "Tuesday" = 2, 
                                                                  "Wednesday" = 3,
                                                                  "Thursday" = 4,
                                                                  "Friday" = 5,
                                                                  "Saturday" = 6,
                                                                  "Sunday" = 7),
                                                   selected = c(1, 2, 3, 4, 5, 6, 7)),
                                sliderInput("TableHourSlider", label = h3("Time of Day"), min = 0, 
                                            max = 24, value = c(0, 24)),
                                width = 3
                            ),
                            mainPanel(
                                titlePanel("Try clicking on different rows"),
                                DT::dataTableOutput("UtilisationTable"),
                                leafletOutput("SelectedLineMap")
                            )
                        )
               ),
               # By Line: Details ---------------------------------------------
               tabPanel("By Line: Details",
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
               # Spacial View -------------------------------------------------
               tabPanel("By Operator: Spacial View",
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
                            mainPanel(
                                plotlyOutput("SpacialView", width = "100%", height = 600)
                            )
                        )
               ),
               # Kepler iframe -----------------------------------------
               tabPanel("Kepler.gl",
                        titlePanel("An iFrame Example"),
                        htmlOutput("Kepler")
               )
    )
)
