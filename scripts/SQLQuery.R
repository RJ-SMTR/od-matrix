library(basedosdados)
library(tidyverse)
library(lubridate)
library(ggplot2)
library(hrbrthemes)
library(plotly)
library(htmlwidgets)

set_billing_id("rj-smtr") # autenticação para acesso aos dados

data <- read_sql("
SELECT *
FROM  `rj-smtr-dev.pytest.BRTCapacity` AS BRTCapacity
  LEFT JOIN `rj-smtr-dev.pytest.BRTStops` AS BRTStops
    ON BRTCapacity.Line = BRTStops.route_id
    AND BRTCapacity.TileID = BRTStops.tile_id

WHERE direction_id = 1
                 ")

IntervalData <- data %>% 
  mutate(
    TotalCapacity = as.numeric(TotalCapacity),
    SittingCapacity = as.numeric(SittingCapacity),
    Interval = ceiling_date(
             as.POSIXct(EnterH3Time, format="%H:%M:%S",tz="ET", origin = '1990-01-01'),
             "30 mins")
    ) %>%
  group_by(Line, stop_name, stop_lat, stop_lon, stop_sequence, Interval) %>%
  summarise(   
    TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
    TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
    TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
  as_tibble() 

IntervalDataLine10 <- IntervalData %>%
  filter(Line == 10) %>%
  group_by(Line, stop_name, stop_lat, stop_lon, stop_sequence) %>%
  summarise(AvgTotalCapacity = mean(TotalCapacity))

# Interval data
p <- ggplot(IntervalData, aes(x = Interval, Line, fill= TotalCapacity)) + 
  geom_tile() +
  scale_x_datetime(date_breaks = "2 hour",
                   date_labels = "%H:%M") + 
  scale_fill_gradient(low="white", high="blue") +
  theme_ipsum() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

ggplotly(p, tooltip=c("TotalCapacity", "TotalSittingCapacity"))
saveWidget(pp, file=paste0( getwd(), "/figs/ggplotlyHeatmap.html"))

# Just line 10
p <- ggplot(IntervalDataLine10, aes(x = Interval, y= stop_name, fill= TotalCapacity)) + 
  geom_tile() +
  scale_x_datetime(date_breaks = "2 hour",
                   date_labels = "%H:%M") + 
  scale_fill_gradient(low="white", high="blue") +
  theme_ipsum() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

ggplotly(p, tooltip=c("TotalCapacity", "TotalSittingCapacity"))

# Maps
library(leaflet)
library(htmltools)

factpal <- colorFactor(topo.colors(5), IntervalDataLine10$stop_sequence)

leaflet(IntervalDataLine10) %>% addTiles() %>%
  addMarkers(~stop_lon, ~stop_lat
              ,label = ~paste0(stop_name, ", Total Capacity: ", round(AvgTotalCapacity))
             #,clusterOptions = ~stop_sequence
             #,color = ~factpal(stop_sequence)
             )

# Plotly map
# change default color scale title
m <- list(colorbar = list(title = "Total Inches"))

# geo styling
g <- list(
  scope = 'brazil',
  showland = TRUE,
  landcolor = toRGB("grey83"),
  subunitcolor = toRGB("white"),
  countrycolor = toRGB("white"),
  showlakes = TRUE,
  lakecolor = toRGB("white"),
  showsubunits = TRUE,
  showcountries = TRUE,
  resolution = 50,
  projection = list(
    type = 'conic conformal',
    rotation = list(lon = -100)
  ),
  lonaxis = list(
    showgrid = TRUE,
    gridwidth = 0.5,
    range = c(-140, -55),
    dtick = 5
  ),
  lataxis = list(
    showgrid = TRUE,
    gridwidth = 0.5,
    range = c(20, 60),
    dtick = 5
  )
)

fig <- plot_geo(IntervalDataLine10, lat = ~stop_lat, lon = ~stop_lon, color = ~AvgTotalCapacity)
fig <- fig %>% add_markers(
  text = ~paste(IntervalDataLine10$AvgTotalCapacity, "inches"), hoverinfo = "text"
)
fig <- fig %>% layout(title = 'US Precipitation 06-30-2015<br>Source: NOAA'
                      #, geo = g
                      )

fig

# ridgeline plot
library(ggridges)
library(hrbrthemes)
library(viridis)

data %>%
  filter(Line == 10) %>%
  #mutate(text = fct_reorder(text, value)) %>%
  ggplot( aes(y=stop_name, x=EnterH3Time,  fill=TotalCapacity)) +
  geom_density_ridges_gradient(bandwidth = 4000) +
  scale_fill_viridis(discrete=FALSE) +
  scale_color_viridis(discrete=FALSE) +
  theme_ipsum() +
  theme(
    legend.position="none",
    panel.spacing = unit(0.1, "lines"),
    strip.text.x = element_text(size = 8)
  ) +
  xlab("") +
  ylab("Assigned Probability (%)")



write.csv(IntervalData, file = "BRT30minIntervalData.csv")
write.csv(data, file = "data.csv")

CapacityData <- data

save(CapacityData, file = "CapacityData18June2021.rdata")

#### JUNK CODE ---------
qmplot(longitude, latitude, data = data %>% filter(ordem == "D13234", data == "2021-06-04"), maptype = "toner-lite", color = I("red"))

test<- data %>% filter(ordem == "D13234")
save(test, file = "test.rdata")

load("Onibus8Days.rdata")

bth <- c(153.023503, -27.468920)

h3Test <- test %>%
  mutate(
    h3 = point_to_h3(input = c(longitude, latitude), res = 9)
  )

distinct(h3Test, h3)

point_to_h3(bth, res = 9) %>%
  unlist() %>%
  h3_to_polygon(., simple = FALSE) %>%
  mapview::mapview()
