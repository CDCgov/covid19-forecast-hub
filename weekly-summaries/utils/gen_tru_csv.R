#' Generate the `truth_data.csv` file 
#' containing the most recent observed 
#' hospitalization data.
#'
#' This script fetches the most recent 
#' observed [COVID-19 or flu hospital
#' admissions data for all states 
#' (including US, DC, and Puerto Rico) 
#' and processes it into the required format 
#' for `truth_data.csv`. The data is sourced 
#' from the CDC's COVID-19 hospitalization
#' data (using the `get_target_data.r` script).
#'
#' The resulting `truth_data.csv` will contain 
#' the following columns:
#' - `week_ending_date`: the week ending date 
#' for the observed data
#' - `location`: two-digit FIPS code associated 
#' with the state
#' - `location_name`: full state name 
#' (including "US" for the US state)
#' - `value`: the number of hospital 
#' admissions (integer)
#'
#' The file is saved in the 
#' `weekly-summaries/output/` directory as 
#' `truth_data.csv`.


library("magrittr") # for %>%


# fetch COVID-19 hospitalization data
covid_data <- forecasttools::pull_nhsn(
  api_endpoint = "https://data.cdc.gov/resource/mpgq-jmmr.json",
  columns = c("totalconfc19newadm"),
  start_date = "2024-11-09"  # replace with appropriate date if needed
) %>%
  dplyr::rename(
    value = totalconfc19newadm,
    date = weekendingdate,
    state = jurisdiction
  ) %>%
  dplyr::mutate(
    date = as.Date(date),
    value = as.numeric(value),
    state = stringr::str_replace(
      state, 
      "USA", 
      "US"
    )
  )

# convert state abbreviation to location code 
# and tp long name
covid_data <- covid_data %>%
  dplyr::mutate(
    location = forecasttools::us_loc_abbr_to_code(state), 
    location_name = forecasttools::location_lookup(
      location, 
      location_input_format = "hub", 
      location_output_format = "long_name")
  ) %>%
  # long name "United States" to "US"
  dplyr::mutate(
    location_name = dplyr::if_else(
      location_name == "United States", 
      "US", 
      location_name)
  )


# filter and format the data
formatted_data <- covid_data %>%
  dplyr::select(
    week_ending_date = date, 
    location, 
    location_name, 
    value
  )

# save to CSV
readr::write_csv(
  formatted_data, 
  "../output/truth_data.csv")

