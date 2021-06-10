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

### Other
# Figure out the most transited line
data_selected <- data %>%
  group_by(ordem) %>%
  summarize(number = n())

# subset data for line 607
data_607 <- data %>%
  filter(ordem %in% c("B31149"))


