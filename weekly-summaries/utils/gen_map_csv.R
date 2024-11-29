#' Generate the `map.csv` file containing 
#' ensemble forecast data.
#'
#' This script loads the latest ensemble 
#' forecast data from the `CovidHub-ensemble` 
#' folder and processes it into the required 
#' format for `map.csv`. The resulting CSV
#'  contains forecast values for all states 
#' (including US, DC, and Puerto Rico),
#' for various forecast horizons, and 
#' quantiles (0.025, 0.5, and 0.975).
#' 
#' The ensemble data is expected to contain 
#' the following columns:
#' - `reference_date`: the date of the forecast
#' - `location`: state abbreviation
#' - `horizon`: forecast horizon
#' - `target`: forecast target (e.g., "wk inc covid hosp")
#' - `target_end_date`: the forecast target date
#' - `output_type`: type of output (e.g., "quantile")
#' - `output_type_id`: quantile value (e.g., 0.025, 0.5, 0.975)
#' - `value`: forecast value
#'
#' The resulting `map.csv` file will have the 
#' following columns:
#' - `location_name`: full state name (including "US" for the US state)
#' - `abbreviation`: state abbreviation
#' - `horizon`: forecast horizon
#' - `target`: forecast target
#' - `target_end_date`: target date for the forecast
#' - `quantile_*`: the quantile forecast values (rounded to two decimal places)
#'
#' The file is saved in the 
#' `weekly-summaries/output/` directory as 
#' `map.csv`.

library("magrittr") # for %>%

# load the latest ensemble data from the model-output folder
ensemble_file <- list.files(
  "../../model-output/CovidHub-ensemble/", 
  pattern = "\\.csv$", full.names = TRUE) %>%
  tail(1)  # the latest file
if (length(ensemble_file) == 0) {
  stop("No ensemble CSV files found in the directory!")
}
ensemble_data <- readr::read_csv(ensemble_file)

# some required cols, need to update
required_columns <- c("reference_date", "target_end_date", "value", "location")
missing_columns <- setdiff(required_columns, colnames(ensemble_data))
if (length(missing_columns) > 0) {
  stop(paste("Missing columns in ensemble data:", paste(missing_columns, collapse = ", ")))
}

# population data, add later to forecasttools
pop_data <- readr::read_csv("../data/pop_locs.csv")
pop_required_columns <- c("abbreviation", "population")
missing_pop_columns <- setdiff(pop_required_columns, colnames(pop_data))
if (length(missing_pop_columns) > 0) {
  stop(paste("Missing columns in population data:", paste(missing_pop_columns, collapse = ", ")))
}


# process ensemble data into the required 
# format for map.csv
map_data <- ensemble_data %>%
  dplyr::mutate(
    reference_date = as.Date(reference_date),
    target_end_date = as.Date(target_end_date),
    value = as.numeric(value)
  ) %>%
  # convert location column (FIPS code) to 
  # full location names
  dplyr::mutate(
    location = forecasttools::location_lookup(
      location, 
      location_input_format = "hub", 
      location_output_format = "long_name"
    )
  ) %>%
  # long name "United States" to "US"
  dplyr::mutate(
    location = dplyr::if_else(
      location == "United States", 
      "US", 
      location)
  ) %>% # add populations
  dplyr::left_join(
    pop_data, 
    by = c("location" = "location_name")
  ) %>% 
  # add quantile columns for per-100k rates 
  # and rounded values
  dplyr::mutate(
    quantile_0.025_per100k = value / as.numeric(population) * 100000,
    quantile_0.5_per100k = value /  as.numeric(population) * 100000,
    quantile_0.975_per100k = value /  as.numeric(population) *100000,
    quantile_0.025_count = value,
    quantile_0.5_count = value,
    quantile_0.975_count = value,
    quantile_0.025_per100k_rounded = round(quantile_0.025_per100k, 2),
    quantile_0.5_per100k_rounded = round(quantile_0.5_per100k, 2),
    quantile_0.975_per100k_rounded = round(quantile_0.975_per100k, 2),
    quantile_0.025_count_rounded = round(quantile_0.025_count),
    quantile_0.5_count_rounded = round(quantile_0.5_count),
    quantile_0.975_count_rounded = round(quantile_0.975_count),
    target_end_date_formatted = format(target_end_date, "%B %d, %Y"),
    reference_date_formatted = format(reference_date, "%B %d, %Y")
  ) %>% # select relevant
  dplyr::select(
    location, 
    quantile_0.025_per100k, 
    quantile_0.5_per100k, 
    quantile_0.975_per100k,
    quantile_0.025_count, 
    quantile_0.5_count, 
    quantile_0.975_count,
    quantile_0.025_per100k_rounded, 
    quantile_0.5_per100k_rounded, 
    quantile_0.975_per100k_rounded,
    quantile_0.025_count_rounded, 
    quantile_0.5_count_rounded, 
    quantile_0.975_count_rounded,
    target, 
    target_end_date, 
    reference_date, 
    target_end_date_formatted, 
    reference_date_formatted
  ) %>% # rename location col
  dplyr::rename(location_name = location)


# save to CSV
readr::write_csv(
  map_data, "../output/map.csv")


