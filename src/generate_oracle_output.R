#' Transform a modeling task represented as a nested list
#' to a single data frame
#'
#' @param task Nested list representing a modeling task,
#' as one entry of the output of [hubUtils::get_round_model_tasks()].
#' Must have a `target_end_date` specification.
#' @return A [`tibble`][tibble::tibble()] of all potentially
#' valid submittable outputs for the modeling task defined in `task`.
#' Each row of the table represents a single valid forecastable quantity
#' (e.g. "`target` X on `target_end_date` Y in `location` Z"),
#' plus a valid submittable output_type for forecasting that quantity.
#' If multiple `output_type`s are accepted for a given valid forecastable
#' quantity, that quantity will be represented multiple times, with
#' one row for each valid associated `output_type`.
flatten_task <- function(task) {
  checkmate::assert_names(
    names(task),
    must.include = c("output_type", "task_ids")
  )
  checkmate::assert_names(
    names(task$task_ids),
    must.include = "target_end_date"
  )
  output_types <- names(task$output_type)

  task_params <- purrr::map(task$task_ids, \(x) c(x$required, x$optional)) |>
    purrr::discard_at(c("horizon", "reference_date"))
  ## discard columns that are redundant with `target_end_date`

  return(do.call(
    tidyr::crossing,
    c(task_params, list(output_type = output_types))
  ))
}


#' Transform a group of modeling task represented as a list of
#' nested lists into a single data frame.
#'
#' Calls [flatten_task()] on each entry of the task list.
#'
#' @param task_list List of tasks. Each entry should itself be
#' be a nested list that can be passed to [flatten_task()].
#' @param .deduplicate deduplicate the output if the same flat
#' configuration is found multiple times while flattening the task list?
#' Default `TRUE`.
#'
#' @return A [`tibble`][tibble::tibble()] of all potentially
#' valid submittable outputs for all the modeling tasks defined in `task_lists`.
#' Each row of the table represents a single valid forecastable quantity
#' (e.g. "`target` X on `target_end_date` Y in `location` Z"),
#' plus a valid submittable output_type for forecasting that quantity.
#' If multiple `output_type`s are accepted for a given valid forecastable
#' quantity, that quantity will be represented multiple times, with
#' one row for each valid associated `output_type`.
#'
flatten_task_list <- function(task_list, .deduplicate = TRUE) {
  flat_tasks <- purrr::map_df(task_list, flatten_task)

  if (.deduplicate) {
    flat_tasks <- dplyr::distinct(flat_tasks)
  }

  return(flat_tasks)
}

#' Generate and save oracle output for the Hub
#'
#' @param hub_path Path to the hub root.
#'
#' @return nothing, invisibly, on success.
generate_oracle_output <- function(hub_path) {
  output_dirpath <- fs::path(hub_path, "target-data")
  fs::dir_create(output_dirpath)
  target_ts <- hubData::connect_target_timeseries(hub_path)

  config_tasks <- hubUtils::read_config(hub_path, "tasks")
  round_ids <- hubUtils::get_round_ids(config_tasks)

  ## this involves duplication given how hubUtils::get_round_model_tasks
  ## behaves by default with round ids created from reference dates,
  ## but we do this this way for completeness / generality
  list_of_task_lists <- purrr::map(round_ids, \(id) {
    hubUtils::get_round_model_tasks(config_tasks, id)
  })

  unique_tasks <- purrr::map_df(list_of_task_lists, flatten_task_list) |>
    dplyr::distinct() |>
    dplyr::mutate(target_end_date = as.Date(.data$target_end_date))

  target_data <- target_ts |>
    forecasttools::hub_target_data_as_of("latest", .drop = TRUE) |>
    dplyr::collect() |>
    dplyr::rename(target_end_date = "date")

  join_key <- intersect(
    colnames(unique_tasks),
    colnames(target_data)
  )

  oracle_data <- dplyr::inner_join(unique_tasks, target_data, by = join_key) |>
    dplyr::mutate(output_type_id = NA) |>
    dplyr::rename(
      oracle_value = "observation"
    )

  output_file <- fs::path(output_dirpath, "oracle-output", ext = "parquet")
  forecasttools::write_tabular_file(oracle_data, output_file)
  invisible()
}

args <- argparser::arg_parser(
  "Generate COVID-19 forecast hub oracle data from timeseries data."
) |>
  argparser::add_argument(
    "--base-hub-path",
    type = "character",
    help = "Path to the COVID-19 Forecast Hub root (default: cwd).",
    default = "."
  ) |>
  argparser::parse_args()

generate_oracle_output(args$base_hub_path)
