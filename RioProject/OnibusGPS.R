load("./DataExplorationShiny/Onibus8Days.rdata")

library(tidyverse)
library(h3)
library(leaflet)
library(colorRamps)
library(lubridate)

#coords <- Onibus8Days %>% select(latitude,longitude)
#h3_index <- geo_to_h3(coords, res = 8)

LeafletFilter <- Onibus8Days %>% filter(data == '2021-06-09'
                                        ,timestamp_captura < ymd_hms("2021-06-09 14:00:00")
                                        ,timestamp_captura > ymd_hms("2021-06-09 13:00:00")
                                        )

h3_index <- geo_to_h3(c(LeafletFilter$latitude,LeafletFilter$longitude), res = 8)

tbl <- table(h3_index) %>%
  tibble::as_tibble()

hexagons <- h3_to_geo_boundary_sf(tbl$h3_index) %>%
  dplyr::mutate(index = tbl$h3_index, DataPoints = tbl$n)

pal <- colorBin(colorRamps::matlab.like2(10000), domain = hexagons$DataPoints)

leaflet(data = hexagons) %>%
  addProviderTiles("Stamen.Toner") %>%
  addPolygons(
    weight = 2,
    color = "white",
    fillColor = ~ pal(DataPoints),
    fillOpacity = 0.8,
    label = ~ sprintf("%i DataPoints (%s)", DataPoints, index)
  )

Summary <- hexagons %>%
            summarise(mean(DataPoints),
                      median(DataPoints),
                      max(DataPoints),
                      min(DataPoints)
                      )

