# R script to create ensemble forecats using models submitted to the CovidHub

parser <- argparser::arg_parser(
  "Create a hub ensemble model for covid-19 hospital admissions"
)
parser <- argparser::add_argument(
  parser, "--reference-date",
  help = "reference date in YYYY-MM-DD format"
)

args <- argparser::parse_args(parser)
reference_date <- as.Date(args$reference_date)

dow_supplied <- lubridate::wday(reference_date,
  week_start = 7,
  label = FALSE
)
if (dow_supplied != 7) {
  cli::cli_abort(message = paste0(
    "Expected `reference_date` to be a Saturday, day number 7 ",
    "of the week, given the `week_start` value of Sunday. ",
    "Got {reference_date}, which is day number ",
    "{dow_supplied} of the week."
  ))
}

hub_path <- "."
task_id_cols <- c(
  "reference_date", "location", "horizon",
  "target", "target_end_date"
)
output_dirpath <- "model-output/"
if (!dir.exists(output_dirpath)) {
  dir.create(output_dirpath, recursive = TRUE)
}

# Get current forecasts from the hub, excluding baseline and ensembles
hub_content <- hubData::connect_hub(hub_path)
current_forecasts <- hub_content |>
  dplyr::filter(
    reference_date == reference_date,
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
    "auxiliary-data",
    paste0(
      as.character(reference_date), "-", "models-to-include-in-ensemble.csv"
    )
  ),
  row.names = FALSE
)

models <- eligible_models$Model
# filter excluded locations
exclude_data <- jsonlite::fromJSON("auxiliary-data/exclude_ensemble.json")
excluded_locations <- exclude_data$locations
current_forecasts <- current_forecasts |>
  dplyr::filter(model_id %in% models, !(location %in% excluded_locations))

# QUANTILE ENSEMBLE
quantile_forecasts <- current_forecasts |>
  dplyr::filter(output_type == "quantile") |>
  # ensure quantiles are handled accurately even with leading/trailing zeros
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
    paste0(as.character(reference_date), "-", "CovidHub-ensemble.csv")
  ),
  row.names = FALSE
)
