# R script to create ensemble forecats using models submitted to the CovidHub

ref_date <- lubridate::ceiling_date(Sys.Date(), "week") - lubridate::days(1)
hub_path <- "../.."
task_id_cols <- c(
  "reference_date", "location", "horizon",
  "target", "target_end_date"
)
out_path <- "CovidHub-ensemble/"

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
designated_models <- purrr::map_chr(yml_files, function(file) {
  yml_data <- yaml::yaml.load_file(file)
  ifelse("designated_model" %in% names(yml_data), yml_data$designated_model, NA)
})

eligible_models <- data.frame(
  Model = tools::file_path_sans_ext(basename(yml_files)),
  Designated_Model = designated_models
) |> dplyr::filter(Designated_Model == TRUE)

eligible_models <- data.frame(
  Model = file.names, Designated_Model = designated_models
) |> filter(Designated_Model == TRUE)

write.csv(
  eligible_models,
  paste0(out_path,
         ref_date,
         "-",
         "models-to-include-in-ensemble",
         ".csv")
)

models <- eligible_models$Model
current_forecasts <- current_forecasts |>
  dplyr::filter(model_id %in% models, location != 78)

# QUANTILE ENSEMBLE
quantile_forecasts <- current_forecasts |>
  dplyr::filter(output_type == "quantile") |>
  dplyr::mutate(output_type_id = as.character(as.numeric(output_type_id)))

median_ensemble_outputs <- quantile_forecasts |>
  hubEnsembles::simple_ensemble(
    agg_fun = "median",
    model_id = "CovidHub-quantile-median-ensemble",
    task_id_cols = task_id_cols
  ) |>
  dplyr::mutate(value = pmax(value, 0)) |>
  dplyr::select(-model_id)

ensemble_name <- "CovidHub-ensemble"
ensemble_path <- paste0(
  out_path, ref_date, "-", ensemble_name, ".csv"
)
write.csv(median_ensemble_outputs, ensemble_path)
