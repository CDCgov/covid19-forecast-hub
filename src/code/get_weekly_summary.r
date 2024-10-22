#Package list to load in CI
library(dplyr)
library(lubridate)
library(hubData)

ref_date <- lubridate::ceiling_date(Sys.Date(), "week") - lubridate::days(1)
hub_path <- "../.."
out_path <- "auxiliary-data/"

hub_content <- hubData::connect_hub(hub_path)
weekly_data <- hub_content |>
  dplyr::filter(reference_date == ref_date) |>
  hubData::collect_hub()

data_path <- paste0(
  out_path, ref_date, "-", "weekly_summary", ".csv"
)

write.csv(
  weekly_data,
  data_path, row.names = FALSE
)