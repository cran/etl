## ----error=TRUE, message=FALSE------------------------------------------------
library(etl)
foo <- etl("foo")

## -----------------------------------------------------------------------------
ggplots <- etl("ggplot2") %>%
  etl_update()
src_tbls(ggplots)

## ----error=TRUE---------------------------------------------------------------
etl_extract.etl_cities %>% args()
etl_transform.etl_cities %>% args()
etl_load.etl_cities %>% args()

## -----------------------------------------------------------------------------
cities <- etl("cities")
str(cities)

## -----------------------------------------------------------------------------
citation("etl")
citation("dplyr")
citation("dbplyr")

