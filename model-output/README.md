# Model outputs folder

This folder contains a set of subdirectories, one for each model, that contains submitted model output files for that model. The structure of these directories and their contents follows general [hubverse model output guidelines](https://hubdocs.readthedocs.io/en/latest/user-guide/model-output.html). Specific documentation for the COVID-19 Forecast Hub follows.


# Data submission instructions

All forecasts should be submitted directly to the [model-output/](./) folder. Data in this directory should be added to the repository through a pull request so that automatic data validation checks are run.

These instructions provide detail about the [data format](#Data-formatting) as well as [validation](#Forecast-validation) that you can do prior to this pull request. In addition, we describe [metadata](https://github.com/hubverse-org/hubTemplate/blob/master/model-metadata/README.md) that each model should provide in the model-metadata folder.

*Table of Contents*

-   [What is a forecast](#What-is-a-forecast)
-   [Target data](#Target-data)
-   [Data formatting](#Data-formatting)
-   [Forecast file format](#Forecast-file-format)
-   [Forecast data validation](#Forecast-validation)
-   [Weekly ensemble build](#Weekly-ensemble-build)
-   [Policy on late submissions](#policy-on-late-or-updated-submissions)

## What is a forecast 

Models are asked to make specific quantitative forecasts about data that will be observed in the future. These forecasts are interpreted as
"unconditional" predictions about the future. That is, they are not
predictions only for a limited set of possible future scenarios in which a certain set of conditions (e.g. vaccination uptake is strong, or new social-distancing mandates are put in place) hold about the future --
rather, they should characterize uncertainty across all reasonable
future scenarios. In practice, all forecasting models make some
assumptions about how current trends in data may change and impact the
forecasted outcome; some teams select a "most likely" scenario or
combine predictions across multiple scenarios that may occur. Forecasts
submitted to this repository will be evaluated against observed data.

We note that other modeling efforts, such as the [Influenza Scenario
Modeling Hub](https://fluscenariomodelinghub.org/), have been
launched to collect and aggregate model outputs from "scenario
projection" models. These models create longer-term projections under a
specific set of assumptions about how the main drivers of the pandemic
(such as non-pharmaceutical intervention compliance, or vaccination
uptake) may change over time.

## Target Data 

This project treats laboratory-confirmed COVID-19 hospital admissions data, and percent of emergency department visits due to COVID-19 as the target ("gold standard") data for forecasting. The specific forecasting targets are epiweekly total incident hospital admissions and epiweekly percent of emergency department visits due to COVID-19.
These data are reported through CDC's NHSN (National Health Safety Network) and NSSP (National Syndromic Surveillance Program) systems.

Further information on the data can be found at the NHSN's [Hospital Respiratory Reporting](https://www.cdc.gov/nhsn/psc/hospital-respiratory-reporting.html) page and NSSP's [Emergency Department Visit Trajectories](https://data.cdc.gov/Public-Health-Surveillance/NSSP-Emergency-Department-Visit-Trajectories-by-St/rdmq-nq56/about_data) page.


## Forecast submission formatting 


The automatic checks in place for forecast files submitted to this
repository validates both the filename and file contents to ensure the
file can be used in the visualization and ensemble forecasting.

### Subdirectory

Each model that submits forecasts for this project will have a unique subdirectory within the [model-output/](model-output/) directory in this GitHub repository where forecasts will be submitted. Each subdirectory must be named

    team-model

where

-   `team` is the team name and
-   `model` is the name of your model.

Both team and model should be less than 15 characters and not include
hyphens or other special characters, with the exception of "\_".

The combination of `team` and `model` should be unique from any other model in the project.


### Metadata

The metadata file will be saved within the model-metdata directory in the Hub's GitHub repository. It should be a YAML file with base name `{team}-{model}`, and extension `.yml` or `.yaml`, e.g.

    exampleteam-examplemodel.yml
    otherteam-othermodel.yaml


Details on the content and formatting of metadata files are provided in the [model-metadata README](https://github.com/hubverse-org/hubTemplate/blob/master/model-metadata/README.md).




### Forecasts

Each forecast file should have the following
format

    {YYYY-MM-DD}-{team}-{model}.csv

or

    {YYYY-MM-DD}-{team}-{model}.parquet

depending on whether the team is submitting forecasts as `.csv` files or as `.parquet` files.

where

-   `YYYY` is the 4 digit year,
-   `MM` is the 2 digit month,
-   `DD` is the 2 digit day,
-   `team` is the abbreviated team name, and
-   `model` is the abbreviated name of your model.

The date YYYY-MM-DD is the [`reference_date`](#reference_date). This should be the Saturday following the submission date. For example, submission from the team above for a reference date of November 2, 2024 will be named:

    2024-11-02-exampleteam-examplemodel.csv

The `team` and `model` in this file must match the `team` and `model` in
the directory this file is in. Both `team` and `model` should be less
than 15 characters, alpha-numeric and underscores only, with no spaces
or hyphens. Submission of both targets- quantiles and samples must be in the same weekly csv or parquet submission file.

## Forecast file format 

The file must be a comma-separated value (csv) file with the following
columns (in any order):

-   `reference_date`
-   `target`
-   `horizon`
-   `target_end_date`
-   `location`
-   `output_type`
-   `output_type_id`
-   `value`

No additional columns are allowed.

The value in each row of the file is either a quantile or sample for a particular combination of location, date, and horizon. 

### `reference_date` 

Values in the `reference_date` column must be a date in the ISO format

    YYYY-MM-DD

This is the date from which all forecasts should be considered. This date is the Saturday following the submission Due Date, corresponding to the last day of the epiweek when submissions are made. The `reference_date` should be the same as the date in the filename but is included here to facilitate validation and analysis. 

### `target`

Values in the `target` column must be a character (string) and be either one or both of the following specific target:

-   `wk inc covid hosp`
-   `wk inc covid prop ed visits`


### `horizon`
Values in the `horizon` column indicate the number of weeks  between the `reference_date` and the `target_end_date`. For submissions to the COVID-19 Forecast Hub, this should be a number between -1 and 3. It indicates the [epidemiological week ("epiweek")](https://epiweeks.readthedocs.io/en/stable/) being forecast/nowcast relative to the epiweek containing the forecast submission date ("the submission epiweek"). 

A `horizon` of -1 indicates that the prediction is a nowcast for ultimately reported data from the epiweek prior to the submission epiweek. A `horizon` of 1 indicates that the prediction is a forecast for the epiweek following submission epiweek.

Note that the COVID-19 Forecast Hub uses [US CDC / MMWR epiweeks](https://ndc.services.cdc.gov/wp-content/uploads/MMWR_Week_overview.pdf), which begin on Sunday and end on Saturday, not [ISO epiweeks](https://en.wikipedia.org/wiki/ISO_week_date).

### `target_end_date`

Values in the `target_end_date` column must be a date in the format

    YYYY-MM-DD
    
This should be a Saturday, the last date of the forecast target's US CDC epiweek. Within each row of the submission file, the `target_end_date` should be equal to the `reference_date` + `horizon`* (7 days).



### `location`

Values in the `location` column must be one of the "locations" in this [file](../auxiliary-data/locations.csv) which includes 2-digit numeric FIPS codes for U.S. states,  territories, and districts, as well as the "US" as a two-character code for national forecasts. 


### `output_type`

Values in the `output_type` column should be one of

-   `quantile` 
-   `samples`

This value indicates whether that row corresponds to a quantile forecast or sample trajectories for weekly incident hospital admissions. Samples can either encode both temporal and spatial dependency across forecast `horizon`s and `location`s or just encode temporal dependency across `horizon` but treats each `location` independently.

### `output_type_id`
Values in the `output_type_id` column specify identifying information for the output type.

#### quantile output

When the predictions are quantiles, values in the `output_type_id` column are a quantile probability level in the format
```
0.###
```
This value indicates the quantile probability level for the `value` in this row.

Teams must provide the following 23 quantiles:


```python
[
    0.01,
    0.025, 
    0.05,
    0.10,
    0.15,
    0.20,
    0.25,
    0.30,
    0.35,
    0.40,
    0.45,
    0.50,
    0.55,
    0.60,
    0.65,
    0.70,
    0.75,
    0.80,
    0.85,
    0.90,
    0.95,
    0.975,
    0.99
]
```



#### sample output

When the predictions are samples, values in the `output_type_id` column are indexes for the samples. The `output_type_id` is used to indicate the dependence across multiple task id variables when samples come from a joint predictive distribution. For example, samples from a joint predictive distribution across `horizon`s for a given `location`, will share `output_type_id` for predictions for different `horizon`s within a same `location`, as shown in the table below:

| origin_date|horizon| location | output_type| output_type_id | value |
|:---------- |:-----:|:-----:| :-------- | :------------ | :---- |
| 2024-10-15 | -1      |  MA | sample | s0 | - |
| 2024-10-15 |  0      |  MA | sample | s0 | - |
| 2024-10-15 |  1      |  MA | sample | s0 | - |
| 2024-10-15 | -1      |  NH | sample | s1 | - |
| 2024-10-15 |  0      |  NH | sample | s1 | - |
| 2024-10-15 |  1      |  NH | sample | s1 | - |
| 2024-10-15 | -1      |  MA | sample | s2 | - |
| 2024-10-15 |  0      |  MA | sample | s2 | - |
| 2024-10-15 |  1      |  MA | sample | s2 | - |
| 2024-10-15 | -1      |  NH | sample | s3 | - |
| 2024-10-15 |  0      |  NH | sample | s3 | - |
| 2024-10-15 |  1      |  NH | sample | s3 | - |

Here, `output_type_id = s0` and `output_type_id = s1` specifies that the predictions
 for horizons -1, 0, and 1 are part of the same joint distribution. Samples from joint 
 distribution across `horizon`s and `location`s can be specified by shared `output_type_id`
  across `location`s and `horizon`s as shown in the example below:

| origin_date|horizon| location | output_type| output_type_id | value |
|:---------- |:-----:|:-----:| :-------- | :------------ | :---- |
| 2024-10-15 | -1      |  MA | sample | S0 | - |
| 2024-10-15 |  0      |  MA | sample | S0 | - |
| 2024-10-15 |  1      |  MA | sample | S0 | - |
| 2024-10-15 | -1      |  NH | sample | S0 | - |
| 2024-10-15 |  0      |  NH | sample | S0 | - |
| 2024-10-15 |  1      |  NH | sample | S0 | - |
| 2024-10-15 | -1      |  MA | sample | S1 | - |
| 2024-10-15 |  0      |  MA | sample | S1 | - |
| 2024-10-15 |  1      |  MA | sample | S1 | - |
| 2024-10-15 | -1      |  NH | sample | S1 | - |
| 2024-10-15 |  0      |  NH | sample | S1 | - |
| 2024-10-15 |  1      |  NH | sample | S1 | - |

The above table shows two samples indexed by `output_type_id:` `S1` and `S2` from a joint predictive distribution across `location`s and `horizon`s.
More details on sample output can be found in the [hubverse documentation of sample output type](https://hubverse.io/en/latest/user-guide/sample-output-type.html).

### `value`

Values in the `value` column are non-negative numbers indicating the "quantile" or "sample" prediction for this row. For a "quantile" prediction, `value` is the inverse of the cumulative distribution function (CDF) for the target, location, and quantile associated with that row. For example, the 2.5 and 97.5 quantiles for a given target and location should capture 95% of the predicted values and correspond to the central 95% Prediction Interval. 

## Forecast validation 

To ensure proper data formatting, pull requests for new data in
`model-output/` will be automatically run. Optionally, you may also run these validations locally.

### Pull request forecast validation

When a pull request is submitted, the data are validated through [Github
Actions](https://docs.github.com/en/actions) which runs the tests
present in [the hubValidations
package](https://github.com/hubverse-org/hubValidations). The
intent for these tests are to validate the requirements above. Please
[let us know](https://github.com/CDCgov/covid19-forecast-hub/issues) if you are facing issues while running the tests.

### Local forecast validation

Optionally, you may validate a forecast file locally before submitting it to the hub in a pull request. Note that this is not required, since the validations will also run on the pull request. To run the validations locally, follow the steps described [here](https://hubverse-org.github.io/hubValidations/articles/validate-submission.html).


## Weekly ensemble build 

Every  Thursday morning, we will generate a  CovidHub ensemble hospital admission forecast using valid forecast submissions in the current week by the Wednesday 11PM ET deadline. Some or all participant forecasts may be combined into an ensemble forecast to be published in real-time along with the participant forecasts. In addition, some or all forecasts may be displayed alongside the output of a baseline model for comparison.


## Policy on late or updated submissions 

In order to ensure that forecasting is done in real-time, all forecasts are required to be submitted to this repository by 11 PM ET on Wednesdays each week. 

### Pre-deadline updates
Teams may submit updates or corrections until the forecast submission deadline.

### Post-deadline corrections
Between the submission deadline and ensemble generation, teams may request to revise a submission to correct technical errors (e.g. accidentally submitting the wrong version of a file). We will consider these correction requests on a case-by-case basis. After the weekly hub ensemble is generated (scheduled for Thursdays at 10 AM US/Eastern Time), no further changes can be made to weekly forecasts. 

Teams should not use the technical correction mechanism as a way to extend the submission deadline, so frequent requests for technical corrections from a single team are more likely to be denied.

### Retrospective baseline models
Teams wishing to contribute a non-designated baseline model to the Hub may request that that retrospective "forecasts" from that baseline model be added to the Hub. We will consider and potentially approve such requests for inclusion in the Hub provided that:

- The model is non-designated
- Its status as a retrospective baseline is declared prominently in the model metadata

## Evaluation criteria
Forecasts will be evaluated using a variety of metrics, including the weighted interval score (WIS).
