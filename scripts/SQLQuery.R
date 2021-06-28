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
FROM  `rj-smtr-dev.pytest.BRTCapacity`
                 ")

IntervalData <- data %>% 
  mutate(
    TotalCapacity = as.numeric(TotalCapacity),
    SittingCapacity = as.numeric(SittingCapacity),
    Interval = ceiling_date(
             as.POSIXct(EnterH3Time, format="%H:%M:%S",tz="ET", origin = '1990-01-01'),
             "30 mins")
    ) %>%
  group_by(Line, Interval) %>%
  summarise(   
    TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
    TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
    TotalCapacity = sum(TotalCapacity, na.rm = TRUE)) %>%
  as_tibble() 

p <- ggplot(IntervalData, aes(x = Interval, Line, fill= TotalCapacity)) + 
  geom_tile() +
  scale_x_datetime(date_breaks = "2 hour",
                   date_labels = "%H:%M") + 
  scale_fill_gradient(low="white", high="blue") +
  theme_ipsum() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

ggplotly(p, tooltip=c("TotalCapacity", "TotalSittingCapacity"))
saveWidget(pp, file=paste0( getwd(), "/figs/ggplotlyHeatmap.html"))

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
