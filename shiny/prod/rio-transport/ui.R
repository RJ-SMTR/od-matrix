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

IntervalData <- read.csv("IntervalData.csv")
BRTOperators <- read.csv("BRTOperatorList.csv")

BRTLineList <- distinct(IntervalData, Line)
BRTOperatorList <- distinct(BRTOperators, Operator)

shinyUI(
    navbarPage("Rio Transport: Prod",
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
                                sliderInput("CapacityHourSliderTable", label = h3("Time of Day"), min = 0, 
                                            max = 24, value = c(0, 24)),
                                width = 2
                            ),
                            mainPanel(
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
               )
    )
)
