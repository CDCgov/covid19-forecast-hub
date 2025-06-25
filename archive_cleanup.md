# Covidhub archive cleanup


``` r
library(fs)
library(tidyverse)
```

    ── Attaching core tidyverse packages ──────────────────────── tidyverse 2.0.0 ──
    ✔ dplyr     1.1.4     ✔ readr     2.1.5
    ✔ forcats   1.0.0     ✔ stringr   1.5.1
    ✔ ggplot2   3.5.2     ✔ tibble    3.2.1
    ✔ lubridate 1.9.4     ✔ tidyr     1.3.1
    ✔ purrr     1.0.4     
    ── Conflicts ────────────────────────────────────────── tidyverse_conflicts() ──
    ✖ dplyr::filter() masks stats::filter()
    ✖ dplyr::lag()    masks stats::lag()
    ℹ Use the conflicted package (<http://conflicted.r-lib.org/>) to force all conflicts to become errors

``` r
library(arrow)
```


    Attaching package: 'arrow'

    The following object is masked from 'package:lubridate':

        duration

    The following object is masked from 'package:utils':

        timestamp

``` r
ts_path <- path("target-data", "time-series", ext = "parquet")
hub_dat <- read_parquet(ts_path)
```

## Investigation

``` r
as_of_max <-
  hub_dat |>
  group_by(as_of) |>
  summarize(max_date = max(date)) |>
  mutate(date_diff = as_of - max_date) |>
  mutate(across(
    where(is.Date),
    \(x) lubridate::wday(x, label = TRUE),
    .names = "{.col}_wday"
  ))
```

Find any time where `as_of` was not a Wednesday or the difference
between `as_of` and `max_date` was not 4 days:

``` r
as_of_max |> filter(date_diff != 4 | as_of_wday != "Wed")
```

| as_of      | max_date   | date_diff | as_of_wday | max_date_wday |
|:-----------|:-----------|:----------|:-----------|:--------------|
| 2024-11-18 | 2024-11-09 | 9 days    | Mon        | Sat           |
| 2024-11-22 | 2024-11-16 | 6 days    | Fri        | Sat           |
| 2024-12-26 | 2024-12-21 | 5 days    | Thu        | Sat           |
| 2025-01-02 | 2024-12-28 | 5 days    | Thu        | Sat           |
| 2025-01-27 | 2025-01-18 | 9 days    | Mon        | Sat           |

`as_of` `2024-12-26` and `2025-01-02` are fine because they are
holidays.

We should remove all the other dates.

`2024-11-22` and `2024-11-18` will be reeoved becasue we have `as_of`
`2024-11-20`:

``` r
as_of_max |> filter(as_of <= "2024-11-22")
```

| as_of      | max_date   | date_diff | as_of_wday | max_date_wday |
|:-----------|:-----------|:----------|:-----------|:--------------|
| 2024-11-18 | 2024-11-09 | 9 days    | Mon        | Sat           |
| 2024-11-20 | 2024-11-16 | 4 days    | Wed        | Sat           |
| 2024-11-22 | 2024-11-16 | 6 days    | Fri        | Sat           |

`as_of` `2025-01-27` will be removed because there was no update
`2025-01-22` and we did not accept forecasts on that date:

``` r
as_of_max |> filter("2025-01-20" <= as_of, as_of <= "2025-01-27")
```

| as_of      | max_date   | date_diff | as_of_wday | max_date_wday |
|:-----------|:-----------|:----------|:-----------|:--------------|
| 2025-01-27 | 2025-01-18 | 9 days    | Mon        | Sat           |

## Fix

``` r
hub_dat_fixed <- hub_dat |>
  filter(!(as_of %in% c("2024-11-18", "2024-11-22", "2025-01-27")))
```

``` r
as_of_max_fixed <-
  hub_dat_fixed |>
  group_by(as_of) |>
  summarize(max_date = max(date)) |>
  mutate(date_diff = as_of - max_date) |>
  mutate(across(
    where(is.Date),
    \(x) lubridate::wday(x, label = TRUE),
    .names = "{.col}_wday"
  ))
```

Find any time where `as_of` was not a Wednesday or the difference
between `as_of` and `max_date` was not 4 days:

``` r
as_of_max_fixed |> filter(date_diff != 4 | as_of_wday != "Wed")
```

| as_of      | max_date   | date_diff | as_of_wday | max_date_wday |
|:-----------|:-----------|:----------|:-----------|:--------------|
| 2024-12-26 | 2024-12-21 | 5 days    | Thu        | Sat           |
| 2025-01-02 | 2024-12-28 | 5 days    | Thu        | Sat           |

Looks good.

``` r
write_parquet(hub_dat_fixed, ts_path)
```
