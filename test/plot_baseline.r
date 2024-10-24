
preds_wide <- epipredict::pivot_quantiles_wider(preds, .pred_distn)
plot_states <- sort(unique(target_epi_df$geo_value))
plot_ncol <- 3L

plt <- preds_wide |>
  filter(geo_value %in% plot_states) |>
  mutate(geo_value = factor(geo_value, plot_states)) |>
  arrange(geo_value) |>
  ggplot2::ggplot(ggplot2::aes(target_date)) +
  ggplot2::geom_ribbon(
    ggplot2::aes(ymin = `0.1`, ymax = `0.9`), fill = blues9[3]
  ) +
  ggplot2::geom_ribbon(
    ggplot2::aes(ymin = `0.25`, ymax = `0.75`), fill = blues9[6]
  ) +
  ggplot2::geom_line(ggplot2::aes(y = .pred), color = "orange") +
  ggplot2::geom_line(
    data = target_epi_df |>
      filter(geo_value %in% plot_states) |>
      mutate(geo_value = factor(geo_value, plot_states)) |>
      arrange(geo_value),
    ggplot2::aes(x = time_value, y = weekly_count)
  ) +
  ggplot2::scale_x_date(limits = c(reference_date - 120, reference_date + 30)) +
  ggplot2::labs(x = "Date", y = "Weekly admissions") +
  ggplot2::facet_wrap(~geo_value, scales = "free_y", ncol = plot_ncol) +
  ggplot2::geom_vline(
    xintercept = as.numeric(desired_max_time_value), linetype = "dotted"
  ) +
  ggplot2::geom_vline(
    xintercept = as.numeric(forecast_as_of_date), linetype = "dotdash"
  ) +
  ggplot2::geom_vline(
    xintercept = as.numeric(reference_date), linetype = "dashed"
  ) +
  ggplot2::theme_bw()

plotly::ggplotly(plt, height = 400 * length(plot_states) / plot_ncol)