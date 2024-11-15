# Obtain covid target data

health_data <- RSocrata::read.socrata(url = "https://data.cdc.gov/resource/ua7e-t2fy.json") |> # nolint
  dplyr::filter(weekendingdate >= as.Date("2024-11-02"))

formatted_data <- health_data |>
  dplyr::select(jurisdiction, weekendingdate, totalconfc19hosppats) |>
  dplyr::rename(
    "value" = "totalconfc19hosppats",
    "date" = "weekendingdate",
    "state" = "jurisdiction"
  ) |>
  dplyr::mutate(
    date = as.Date(date),
    value = as.numeric(value),
    state = stringr::str_replace(state, "USA", "US")
  )

output_dirpath <- "target-data/"
write.csv(
  formatted_data,
  file.path(output_dirpath, "covid-hospital-admissions.csv"),
  row.names = FALSE
)
