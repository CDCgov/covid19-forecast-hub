# Target data
This folder contains target data in [standard hubverse format](https://docs.hubverse.io/en/latest/user-guide/target-data.html), [`time-series.parquet`](time-series.parquet) with both weekly incident COVID-19 hospital admissions and weekly incident proportion of emergency department visits data. This `time-series.parquet` will be treated as the truth data for (eventual) evaluation of the forecasts submitted to the CovidHub.

### Target Data Dictionary

The following columns are included in `time-series.parquet`:

| Column      | Description                                                        |
|-------------|--------------------------------------------------------------------|
| `date`      | Date of observation (YYYY-MM-DD)                                   |
| `location`  | Location code (2 digits FIPS or `"US"` for national data)          |
| `observation` | Numeric value for the target                                     |
| `as_of`     | Date the data was retrieved or processed                           |
| `target`    | Description of the metric (e.g., `"wk inc covid hosp"`)            |


### Deprecation Notice
The legacy version of target data containing just the COVID-19 hospital admissions data named [`covid-hospital-admissions.csv`](covid-hospital-admissions.csv) is being deprecated and will eventually be removed from this repository.   *Please update any workflows or scripts to use `time-series.parquet` instead.*


## Hospital Admissions Data
The hospital admission prediction target `wk inc covid hosp` is the weekly number of confirmed COVID-19 hospital admissions based on [NHSN Hospital Respiratory Reporting](https://www.cdc.gov/nhsn/psc/hospital-respiratory-reporting.html). [Weekly official counts](https://data.cdc.gov/Public-Health-Surveillance/Weekly-Hospital-Respiratory-Data-HRD-Metrics-by-Ju/ua7e-t2fy/about_data) are publicly released on Fridays. [Preliminary counts](https://data.cdc.gov/Public-Health-Surveillance/Weekly-Hospital-Respiratory-Data-HRD-Metrics-by-Ju/mpgq-jmmr/about_data) are released on Wednesdays. We update files in this target-data directory every Wednesday with latest reported incident COVID-19 admissions values.

## Emergency Department Visits Data
The emergency department visits prediction target `wk inc covid prop ed visits` is the weekly proportion of emergency department (ED) visits due to COVID-19 based on [National Syndromic Surveillance Program](https://www.cdc.gov/nssp/index.html) (NSSP) [Emergency Department Visits - COVID-19, Flu, RSV, Sub-state](https://data.cdc.gov/Public-Health-Surveillance/NSSP-Emergency-Department-Visit-Trajectories-by-St/rdmq-nq56/about_data) dataset. Although these numbers are reported in the percentage form, we accept forecasts as decimal proportions. The target data values are therefore expressed that way in the [`time-series.parquet`](time-series.parquet) target data file. 

The Wednesday release of NSSP [Emergency Department Visits - COVID-19, Flu, RSV, Sub-state](https://data.cdc.gov/Public-Health-Surveillance/NSSP-Emergency-Department-Visit-Trajectories-by-St/rdmq-nq56/about_data) dataset will be available around mid-July on data.cdc.gov. Until then, we will maintain a copy of the dataset and update it every Wednesday in the [`auxiliary-data/nssp-raw-data`](../auxiliary-data/nssp-raw-data) directory of our GitHub repository as a file named [`latest.csv`](../auxiliary-data/nssp-raw-data/latest.csv).
In addition to this raw dataset, `wk inc covid prop ed visits` is included in the [`time-series.parquet`](time-series.parquet) which is updated every Wednesday.
