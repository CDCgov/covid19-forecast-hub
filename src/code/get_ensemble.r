# R script to create ensemble forecats using models submitted to the CovidHub

ref_date <- lubridate::ceiling_date(Sys.Date(), "week") - lubridate::days(1)
hub_path <- "."
task_id_cols <- c(
  "reference_date", "location", "horizon",
  "target", "target_end_date"
)
output_dirpath <- "CovidHub-ensemble/"
if (!dir.exists(output_dirpath)) {
  dir.create(output_dirpath, recursive = TRUE)
}

# Get current forecasts from the hub, excluding baseline and ensembles
hub_content <- hubData::connect_hub(hub_path)
current_forecasts <- hub_content |>
  dplyr::filter(
    reference_date == ref_date,
    !str_detect(model_id, "CovidHub")
  ) |>
  hubData::collect_hub()

yml_files <- list.files(paste0(hub_path, "/model-metadata"),
  pattern = "\\.ya?ml$", full.names = TRUE
)

# Read model metadata and extract designated models
is_model_designated <- function(yaml_file) {
  yml_data <- yaml::yaml.load_file(yaml_file)
  team_and_model <- glue::glue("{yml_data$team_abbr}-{yml_data$model_abbr}")
  is_designated <- ifelse("designated_model" %in% names(yml_data),
    as.logical(yml_data$designated_model),
    FALSE
  )
  return(list(Model = team_and_model, Designated_Model = is_designated))
}

eligible_models <- purrr::map(yml_files, is_model_designated) |>
  dplyr::bind_rows() |>
  dplyr::filter(Designated_Model)

write.csv(
  eligible_models,
  file.path(
    output_dirpath,
    paste0(as.character(ref_date), "-", "models-to-include-in-ensemble.csv")
  ),
  row.names = FALSE
)

models <- eligible_models$Model
#filter excluded locations
exclude_data <- jsonlite::fromJSON("auxiliary-data/exclude_ensemble.json")
excluded_locations <- exclude_data$locations
current_forecasts <- current_forecasts |>
  dplyr::filter(model_id %in% models, !(location %in% excluded_locations))

# QUANTILE ENSEMBLE
quantile_forecasts <- current_forecasts |>
  dplyr::filter(output_type == "quantile") |>
  #ensure quantiles are handled accurately even with leading/trailing zeros
  dplyr::mutate(output_type_id = as.factor(as.numeric(output_type_id)))

median_ensemble_outputs <- quantile_forecasts |>
  hubEnsembles::simple_ensemble(
    agg_fun = "median",
    model_id = "CovidHub-quantile-median-ensemble",
    task_id_cols = task_id_cols
  ) |>
  dplyr::mutate(value = pmax(value, 0)) |>
  dplyr::select(-model_id)

write.csv(
  median_ensemble_outputs,
  file.path(
    output_dirpath,
    paste0(as.character(ref_date), "-", "CovidHub-ensemble.csv")
  ),
  row.names = FALSE
)
