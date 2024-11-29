#' Pivot a hubverse quantile table wider with columns representing
#' individual quantile levels.
#'
#' @param hubverse_table hubverse-format forecast table to pivot,
#' as a [`tibble`][tibble::tibble()]
#' @param pivot_quantiles quantiles to pivot to columns, as a vector or
#' named vector. Default `c("point" = 0.5, "lower" = 0.025, "upper" = 0.975)`,
#' i.e. get the median and the central 95% interquantile interval,
#' with names "point" for the median, "lower" for the 0.025th quantile,
#' and "upper" for the 0.975th quantile.
#' @return A pivoted version of the hubverse table in which each
#' forecast for a given target, horizon, reference_date, and
#' location corresponds to a single row with multiple
#' value columns, one for each of the quantiles in `pivot_quantiles`,
#' and named according to the corresponding names given in that vector,
#' or generically as `q_<quantile_level>` if an unnamed numeric
#' vector is provided.
#' So with the default `pivot_quantiles`, the output will have three
#' value columns named `lower"`, `"point"`, and `"upper"`
#' @export
pivot_hubverse_quantiles_wider <- function(hubverse_table,
                                           pivot_quantiles = c(
                                             "point" = 0.5,
                                             "lower" = 0.025,
                                             "upper" = 0.975
                                           )) {
  if (!("quantile" %in% hubverse_table$output_type)) {
    cli::cli_abort(message = paste0(
      "Hubverse table must contain at least ",
      "one quantile forecast."
    ))
  }

  dat <- hubverse_table |>
    dplyr::filter(.data$output_type == "quantile") |>
    dplyr::mutate("output_type_id" = as.numeric(.data$output_type_id))

  pivot_quantiles_present <- pivot_quantiles %in% hubverse_table$output_type_id

  if (!all(pivot_quantiles_present)) {
    missing_pivot_quantiles <- pivot_quantiles[!pivot_quantiles_present]
    cli::cli_abort(message = paste0(
      "Hubverse table is missing one or more of ",
      "the requested pivot quantiles for all forecasts. ",
      "The following requested pivot quantiles ",
      "could not be found: {missing_pivot_quantiles}."
    ))
  }

  if (is.null(names(pivot_quantiles))) {
    names(pivot_quantiles) <- paste("q", pivot_quantiles, sep = "")
  }

  pivot_quant_map <- setNames(names(pivot_quantiles), pivot_quantiles)

  dat <- dat |>
    dplyr::filter(.data$output_type_id %in% !!pivot_quantiles) |>
    dplyr::mutate(
      "which_quantile" = dplyr::recode(
        .data$output_type_id,
        !!!pivot_quant_map
      )
    ) |>
    dplyr::select(-"output_type", -"output_type_id") |>
    tidyr::pivot_wider(
      names_from = "which_quantile",
      values_from = "value"
    )
  return(dat)
}