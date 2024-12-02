#' Generate the `all_forecasts.csv` file 
#' containing all model submissions
#'
#' This script fetches all forecast submissions from the 
#' covid19-forecast-hub based on the 
#' `reference_date`. The 
#' forecast data is then pivoted to 
#' create a wide format with quantile levels 
#' as columns. 
#'
#' The resulting `all_forecasts.csv` will 
#' contain the following columns:
#' - `location_name`: full state name 
#' (including "US" for the US state)
#' - `abbreviation`: state abbreviation
#' - `horizon`: forecast horizon
#' - `forecast_date`: date the forecast was generated
#' - `target_end_date`: target date for the forecast
#' - `model`: model name
#' - `quantile_*`: forecast values for various quantiles (e.g., 0.025, 0.5, 0.975)
#' - `forecast_teams`: name of the team that generated the model
#' - `forecast_fullnames`: full model name
#'
#' The file is saved in the 
#' `weekly-summaries/output/` directory as 
#' `all_forecasts.csv`.


library("magrittr") # for %>%


# # excluded locations (from external data file)
# # only for the first week; this should 
# # check for output data, if csv found, 
# # then do not use
# exclude_data <- jsonlite::fromJSON(
#   "../../auxiliary-data/2024-11-23-exclude-locations.json")
# excluded_locations <- exclude_data$locations

# reference date and paths
reference_date <- as.Date("2024-11-23")
hub_path <- "../../"  
hub_content <- hubData::connect_hub(hub_path)


# filter content based on ref date, 
# exclude baseline and ensembles
current_forecasts <- hub_content |>
  dplyr::filter(
    reference_date == !!reference_date, 
    !str_detect(model_id, "CovidHub")
  ) |>
  hubData::collect_hub()



all_forecasts_data <- forecasttools::pivot_hubverse_quantiles_wider(
  hubverse_table = current_forecasts,
  pivot_quantiles = c("point" = 0.5, "lower" = 0.025, "q25" = 0.25, "q75" = 0.75, "upper" = 0.975)  
) %>%
  # dplyr::filter(!(location %in% excluded_locations)) %>%
  # convert location to full location names 
  # and abbreviations
  dplyr::mutate(
    location_name = forecasttools::location_lookup(
      location, 
      location_input_format = "hub", 
      location_output_format = "long_name"
    ),
    abbreviation = forecasttools::us_loc_code_to_abbr(location)
  ) %>%
  # round the quantiles to nearest integer 
  # for rounded versions (2 places?)
  dplyr::mutate(
    quantile_0.025_rounded = round(lower),
    quantile_0.25_rounded = round(q25),
    quantile_0.5_rounded = round(point),
    quantile_0.75_rounded = round(q75),
    quantile_0.975_rounded = round(upper)
  ) %>%
  dplyr::select(
    location_name,
    abbreviation,
    horizon,
    forecast_date = reference_date,  # rename reference_date to forecast_date
    target_end_date,
    model_id = model, # rename model_id to model
    quantile_0.025 = lower,  # rename lower to quantile_0.025
    quantile_0.25 = q25, # rename q25 to quantile_0.25
    quantile_0.5 = point, # rename point to quantile_0.5
    quantile_0.75 = q75, # rename q75 to quantile_0.75
    quantile_0.975 = upper,  # rename upper to quantile_0.975
    quantile_0.025_rounded,
    quantile_0.25_rounded,
    quantile_0.5_rounded,
    quantile_0.75_rounded,
    quantile_0.975_rounded
  )

# # process forecasts into the required format
# all_forecasts_data <- current_forecasts %>%
#   # get long name from code and make 
#   # abbreviation col
#   dplyr::mutate(
#     location_name = forecasttools::location_lookup(
#       location, 
#       location_input_format = "code", 
#       location_output_format = "long_name"
#     ),
#     abbreviation = forecasttools::us_loc_code_to_abbr(location)
#   ) %>%
#   # pivot data to get separate quantiles 
#   # in different columns
#   tidyr::pivot_wider(
#     names_from = output_type_id, 
#     values_from = value,
#     names_prefix = "quantile_",
#     values_fn = list(value = ~first(.))
#   ) %>%
#   dplyr::mutate(
#     quantile_0.025_rounded = round(quantile_0.025),
#     quantile_0.25_rounded = round(quantile_0.25),
#     quantile_0.5_rounded = round(quantile_0.5),
#     quantile_0.75_rounded = round(quantile_0.75),
#     quantile_0.975_rounded = round(quantile_0.975)
#   ) %>%
#   dplyr::select(
#     location_name,
#     abbreviation,
#     horizon,
#     forecast_date = reference_date,  # rename reference_date to forecast_date
#     target_end_date,
#     model_id,
#     quantile_0.025,
#     quantile_0.25,
#     quantile_0.5,
#     quantile_0.75,
#     quantile_0.975,
#     quantile_0.025_rounded,
#     quantile_0.25_rounded,
#     quantile_0.5_rounded,
#     quantile_0.75_rounded,
#     quantile_0.975_rounded,
#     forecast_teams,
#     forecast_fullnames
#   )


# save to CSV
readr::write_csv(
  all_forecasts_data, 
  "../output/all_forecasts.csv")


