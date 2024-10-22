#' Obtain covid counts at daily or weekly scale
#'
#' @param temporal_resolution "daily" or "weekly"
#' @param remove_na boolean indicating whether NA values should be dropped when
#'   aggregating state-level values and calculating weekly totals. Defaults to
#'   `TRUE`
#'
#' @return data frame of covid incidence with columns date, location,
#'   location_name, value, weekly_rate

fetch_covid <- function(temporal_resolution = "weekly", remove_na = TRUE) {
  health_data <- RSocrata::read.socrata(url = "https://healthdata.gov/resource/g62h-syeh.json") |> # nolint
    dplyr::filter(date >= as.Date("2024-02-02"))

  recent_data <- health_data |>
    dplyr::select(state, date, previous_day_admission_adult_covid_confirmed) |>
    dplyr::rename("value" = "previous_day_admission_adult_covid_confirmed") |>
    dplyr::mutate(
      date = as.Date(date),
      value = as.numeric(value),
      epiweek = lubridate::epiweek(date),
      epiyear = lubridate::epiyear(date)
    )

  # summarize US covid counts
  us_data <- recent_data |>
    dplyr::group_by(date, epiweek, epiyear) |>
    dplyr::summarise(value = sum(value, na.rm = remove_na)) |>
    dplyr::mutate(state = "US") |>
    dplyr::ungroup()

  # bind state and US data
  full_data <- rbind(recent_data, us_data) |>
    dplyr::left_join(locations, by = dplyr::join_by("state" == "abbreviation"))

  # convert counts to weekly
  weeklydat <- full_data |>
    dplyr::group_by(state, epiweek, epiyear, location, location_name) |>
    dplyr::summarise(value = sum(value, na.rm = remove_na),
                     date = max(date),
                     num_days = dplyr::n()) |>
    dplyr::ungroup() |>
    dplyr::filter(num_days == 7L) |>
    dplyr::select(-num_days, -epiweek, -epiyear)

  # if daily data is ever wanted, this returns correct final data
  if (temporal_resolution == "weekly") {
    final_dat <- weeklydat |>
      dplyr::select(date, location, location_name, value) |>
      dplyr::arrange(dplyr::desc(date))
  } else {
    final_dat <- full_data
  }
  return(final_dat)

}

locations <- read.csv(file = "target-data/locations.csv") |>
  dplyr::select(abbreviation, location, location_name)

target_data <- fetch_covid(temporal_resolution = "weekly")

write.csv(target_data, file = "./target-data/target-hospital-admissions.csv")
