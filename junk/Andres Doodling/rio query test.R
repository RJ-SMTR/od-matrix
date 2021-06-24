library(basedosdados)
library(tidyverse)
set_billing_id("rj-smtr")


pib_per_capita <- ' 
SELECT *
FROM `rj-smtr.br_rj_riodejaneiro_onibus_gps.registros_tratada` as dat 
WHERE ordem = "C30238" AND data = "2021-06-04"
LIMIT 1000'

data <- read_sql(pib_per_capita)


ggplot(data = data, aes(x = latitude, y = longitude)) +
  geom_point() + theme_classic()


#H3
library(h3)
library(tidyverse)
library(leaflet)

# Get the coordinates and turn them into h3
coords <- data %>% select(latitude,longitude)
resolution <- 8
h3_index <- geo_to_h3(coords, resolution)


tbl <- table(h3_index) %>%
  tibble::as_tibble()
hexagons <- h3_to_geo_boundary_sf(tbl$h3_index) %>%
  dplyr::mutate(index = tbl$h3_index, accidents = tbl$n)
head(hexagons)


# Making the plot in leaflet
pal <- colorBin("YlOrRd", domain = hexagons$accidents)

map <- leaflet(data = hexagons, width = "100%") %>%
  addProviderTiles("Stamen.Toner") %>%
  addPolygons(
    weight = 2,
    color = "white",
    fillColor = ~ pal(accidents),
    fillOpacity = 0.8,
    label = ~ sprintf("%i accidents (%s)", accidents, index)
  )

map

### Other
# Figure out the most transited line
data_selected <- data %>%
  group_by(ordem) %>%
  summarize(number = n())

# subset data for line 607
data_607 <- data %>%
  filter(ordem %in% c("B31149"))


