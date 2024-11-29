#' Generate the `all_forecasts.csv` file 
#' containing all model submissions
#'
#' This script fetches all COVID-19 or 
#' flu model submissions from the specified 
#' hub, filters the data based on the 
#' `reference_date`, and excludes any 
#' submissions from the `CovidHub` model. The 
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
#' s`all_forecasts.csv`.

# connect to hub, excluding baseline and 
# ensembles, i.e. only getting model
# submissions
hub_path <- "../../"
task_id_cols <- c(
  "reference_date", "location", "horizon",
  "target", "target_end_date"
)
hub_content <- hubData::connect_hub(hub_path)
current_forecasts <- hub_content |>
  dplyr::filter(
    reference_date == !!reference_date,
    !str_detect(model_id, "CovidHub")
  ) |>
  hubData::collect_hub()

# filter for forecasts from all models
current_forecasts <- hub_content %>%
  dplyr::filter(
    reference_date == as.Date("2024-11-23"), 
    !stringr::str_detect(
      model_id, 
      "CovidHub")
  ) %>%
  hubData::collect_hub()

# process forecasts into the required format
all_forecasts_data <- current_forecasts %>%
  # assume columns are `model_id`, 
  # `location`, `forecast_date`, `horizon`, etc.
  dplyr::mutate(
    location_name = dplyr::case_when(
      location == "US" ~ "US",
      TRUE ~ location_name
    )
  ) %>%
  dplyr::select(
    location_name,
    abbreviation,
    horizon,
    forecast_date,
    target_end_date,
    model_id,
    quantile_0.025,
    quantile_0.25,
    quantile_0.5,
    quantile_0.75,
    quantile_0.975,
    quantile_0.025_rounded,
    quantile_0.25_rounded,
    quantile_0.5_rounded,
    quantile_0.75_rounded,
    quantile_0.975_rounded,
    forecast_teams,
    forecast_fullnames
  )

# save to CSV
readr::write_csv(
  all_forecasts_data, 
  "../output/all_forecasts.csv")


