create_new_round <- function(hub_path, ref_date, horizon_range, location) {
  origin_date <- hubAdmin::create_task_id(
    "reference_date",
    required = NULL,
    optional = as.character(ref_date)
  )

  location <- hubAdmin::create_task_id(
    "location",
    required = NULL,
    optional = location
  )

  horizon <- hubAdmin::create_task_id(
    "horizon",
    required = NULL,
    optional = horizon_range
  )

  target_end_date <- hubAdmin::create_task_id(
    "target_end_date",
    required = NULL,
    optional = as.character(ref_date + 7 * horizon_range)
  )

  target <- hubAdmin::create_task_id(
    "target",
    required = NULL,
    optional = c("wk inc covid hosp", "wk inc covid prop ed visits")
  )

  task_ids <- hubAdmin::create_task_ids(
    origin_date, location, horizon, target_end_date, target
  )

  quantile_out_type <- hubAdmin::create_output_type_quantile(
    required = c(0.01, 0.025, seq(0.05, 0.95, by = 0.05), 0.975, 0.99),
    is_required = FALSE,
    value_type = "double",
    value_minimum = 0
  )

  sample_out_type <- hubAdmin::create_output_type_sample(
    is_required = FALSE,
    output_type_id_type = "character",
    max_length = 15L,
    min_samples_per_task = 200L,
    max_samples_per_task = 200L,
    compound_taskid_set = "location",
    value_type = "double",
    value_minimum = 0
  )

  target_metadata_admissions <- hubAdmin::create_target_metadata_item(
    target_id = "wk inc covid hosp",
    target_name = "incident covid hospitalizations",
    target_units = "count",
    target_keys = list(target = "wk inc covid hosp"),
    target_type = "continuous",
    description = "This target represents the count of new hospitalizations in the week ending on the date [horizon] weeks after the reference_date, on the target_end_date.", # nolint
    is_step_ahead = TRUE,
    time_unit = "week"
  )
  target_metadata_ed_visits <- hubAdmin::create_target_metadata_item(
    target_id = "wk inc covid prop ed visits",
    target_name = "proportion of weekly incident ED visits due to COVID-19",
    target_units = "proportion",
    target_keys = list(target = "wk inc covid prop ed visits"),
    target_type = "continuous",
    description = "This target represents the proportion of emergency department visits due to COVID-19 in the week ending on the date [horizon] weeks after the reference_date, on the target_end_date.", # nolint
    is_step_ahead = TRUE,
    time_unit = "week"
  )

  model_task_hosp_admissions <- hubAdmin::create_model_task(
    task_ids = task_ids,
    output_type = hubAdmin::create_output_type(
      quantile_out_type, sample_out_type
    ),
    target_metadata = hubAdmin::create_target_metadata(
      target_metadata_admissions, target_metadata_ed_visits
    )
  )

  round <- hubAdmin::create_round(
    round_id_from_variable = TRUE,
    round_id = "reference_date",
    model_tasks = hubAdmin::create_model_tasks(model_task_hosp_admissions),
    submissions_due = list(
      relative_to = "reference_date",
      start = -6L,
      end = -3L
    )
  )

  return(round)
}


parser <- argparser::arg_parser("Create a new round config for the COVIDhub")

parser <- argparser::add_argument(
  parser,
  "--hub-path",
  help = "Path to the Covid19 forecast hub directory.",
  default = "."
)
parser <- argparser::add_argument(
  parser,
  "--ref-date",
  default = forecasttools::ceiling_mmwr_epiweek(lubridate::today()),
  help = "Reference date in YYYY-MM-DD format. Defaults to the next Saturday."
)
parser <- argparser::add_argument(
  parser,
  "--horizon-range",
  type = "integer",
  default = -1:3,
  help = "Horizon range in weeks. (default: -1:3)."
)
parser <- argparser::add_argument(
  parser,
  "--location",
  type = "character",
  default = c(
    "US", "01", "02", "04", "05", "06", "08", "09", "10", "11", "12", "13",
    "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26",
    "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38",
    "39", "40", "41", "42", "44", "45", "46", "47", "48", "49", "50", "51",
    "53", "54", "55", "56", "72"
  ),
  help = "Location codes for forecasting jurisdiction.
    (default: 50 states, DC, US)."
)

args <- argparser::parse_args(parser)
hub_path <- args$hub_path
reference_date <- as.Date(args$ref_date)
horizon_range <- args$horizon_range
location <- args$location

round <- create_new_round(hub_path, reference_date, horizon_range, location)

existing_task_config <- try(
  hubUtils::read_config(hub_path, config = c("tasks"))
)
if (inherits(existing_task_config, "try-error")) {
  cli::cli_alert_info(
    "Existing config not found, creating a new {.file tasks.json}"
  )
  new_task_config <- hubAdmin::create_config(hubAdmin::create_rounds(round))
} else {
  cli::cli_alert_info("Existing config found, adding a new round")
  new_task_config <- hubAdmin::append_round(existing_task_config, round)
}
hubAdmin::write_config(new_task_config, hub_path = hub_path, overwrite = TRUE)
valid_task_config <- hubAdmin::validate_config(
  hub_path = hub_path, config = c("tasks"), schema_version = "from_config"
)
if (isFALSE(valid_task_config)) {
  cli::cli_alert_danger("Generated task config (tasks.json) is invalid")
  stop()
}
cli::cli_h1("New round added to {.file tasks.json}")
