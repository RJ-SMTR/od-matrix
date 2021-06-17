library(basedosdados)
library(tidyverse)
library(lubridate)

set_billing_id("rj-smtr") # autenticação para acesso aos dados

data <- read_sql("
WITH GPSTable AS (
    SELECT *,
        ST_GEOGPOINT(longitude, latitude) AS geography

    FROM `rj-smtr.br_rj_riodejaneiro_onibus_gps.registros_tratada`
    ),

H3Table AS (
    SELECT  tile_id,
            resolution,
            parent_id,
            ST_GEOGFROMTEXT(geometry) AS geometry

    FROM `rj-smtr.br_rj_riodejaneiro_geo.h3_res8` 
    ),

GPSH3Table AS (
    SELECT 
        ordem,
        data,
        tile_id,
        resolution,
        parent_id,
        hora_completa,
        CASE
            WHEN LAG(tile_id) OVER (ORDER BY ordem, data, hora_completa) = tile_id THEN 'DROP'
            ELSE 'KEEP'
        END AS RemoveRowLag

    FROM GPSTable --15,410,765 rows in table, inner join table returned 15,161,095 rows.

    JOIN H3Table -- This appears to be an inner join which isn't ideal (may drop data). Why doesn't left join work?
        ON ST_INTERSECTS(GPSTable.geography, H3Table.geometry)
)

SELECT 
    GPSH3Table.data,
    GPSH3Table.ordem,
    tile_id,
    hora_completa AS EnterH3Time,
    LEAD(hora_completa) OVER 
        (PARTITION BY GPSH3Table.ordem, GPSH3Table.data 
        ORDER BY GPSH3Table.ordem, GPSH3Table.data, hora_completa) AS ExitH3Time,
    capacidade_sentados AS SittingCapacity,
    capacidade_em_pe AS StandingCapacity,
    capacidade_sentados + capacidade_em_pe AS TotalCapacity
FROM GPSH3Table 
    LEFT JOIN `br_rj_riodejaneiro_transporte.veiculos_licenciados` AS VehicleTable
    ON GPSH3Table.ordem = VehicleTable.ordem
    LEFT JOIN `br_rj_riodejaneiro_transporte.plantas_chasis` AS VehicleDetailsTable
    ON VehicleTable.planta_chassi = VehicleDetailsTable.planta_chassi

WHERE RemoveRowLag = 'KEEP'
AND GPSH3Table.data = '2021-06-11'
ORDER BY GPSH3Table.ordem, GPSH3Table.data, hora_completa
                 ")

IntervalData <- data %>% 
  mutate(
    Interval = ceiling_date(
             as.POSIXct(EnterH3Time, format="%H:%M:%S",tz="ET", origin = '1990-01-01'),
             "30 mins")
    ) %>%
  group_by(Interval, tile_id) %>%
  summarise(   
    TotalSittingCapacity = sum(SittingCapacity, na.rm = TRUE),
    TotalStandingCapacity = sum(StandingCapacity, na.rm = TRUE),
    TotalCapacity = sum(TotalCapacity, na.rm = TRUE))

write.csv(IntervalData, file = "30minIntervalData.csv")
write.csv(data, file = "data.csv")

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
