# Model metadata

This folder contains metadata files for the models submitting to the  COVID-19 Forecast Hub. The specification for these files has been adapted to be consistent with [model metadata guidelines in the hubverse documentation](https://hubdocs.readthedocs.io/en/latest/user-guide/model-metadata.html).

Each model is required to have metadata in [yaml format](https://docs.ansible.com/ansible/latest/reference_appendices/YAMLSyntax.html).


These instructions provide detail about the [data
format](#Data-format) as well as [validation](#Data-validation) that
you can do prior to a pull request with a metadata file.

# Data format
This section describes each of the fields (keys) in the YAML document. Please order the variables in this order in your YAML metadata file.

## Required fields
The following metadata fields are mandatory.

### `team_name`
The full name of your team. Must be fewer than 50 characters.

### `team_abbr`
An abbreviated (<16 character) name for your team.

### `model_name`
The full name of your model. Must be fewer than 50 characters.

### `model_abbr`
An abbreviated (<16 character) name for your model.

### `model_contributors`

A list of all individuals involved in producing the model.
For each contributor, please provide a name, affiliation, and email address. Individually may optionally provide [ORCID](https://orcid.org/) identifiers.

Use the following YAML syntax
```
model_contributors: [
  {
    "name": "Modeler Name 1",
    "affiliation": "Institution Name 1",
    "email": "modeler1@example.com",
    "orcid": "1234-1234-1234-1234"
  },
  {
    "name": "Modeler Name 2",
    "affiliation": "Institution Name 2",
    "email": "modeler2@example.com",
    "orcid": "1234-1234-1234-1234"
  }
]
```

All email addresses provided will be added to an email distribution list through which the Hub makes announcements to model contributors. You can unsubscribe from this list at any time.

### `license`

One of the following [accepted licenses](https://github.com/CDCgov/covid19-forecast-hub/blob/37f4ffdd57c0dc2d8372b674728304e37a46212f/hub-config/model-metadata-schema.json#L69-L75) by inputting `license: <license code>` with one of the following codes. The license you pick will govern future use of the forecast data you contribute to the Hub.

 - `CC-BY-4.0`: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/deed.en)
 - `CC0-1.0`: [CC0 1.0 Universal (public domain declaration)](https://creativecommons.org/publicdomain/zero/1.0/deed.en)
 - `CC-BY_SA-4.0`: [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/deed.en)
 - `PPDL`: [Public Domain Dedication and License](https://opendatacommons.org/licenses/pddl/summary/)
 - `ODC-by`: [Open Data Commons Attribution License](https://opendatacommons.org/licenses/by/1-0/)
 - `ODbL`: [Open Data Commons Open Database License](https://opendatacommons.org/licenses/odbl/)
 - `OGL-3.0`: [UK National Archives Open Government License 3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) 

### `designated_model`

A team-specified boolean indicator (`true` or `false`) for whether the model should be considered eligible for inclusion in Hub ensembles and public visualizations. A team may specify up to two models as `designated_model`s for inclusion. Models which have a designated_model value of `false` will still be included in internal forecasting Hub evaluations, but not in published ensembles and visualizations.

### `data_inputs`

List or description of the data sources used to inform the model, in particular any dataset used that are not the [target dataset](../README.md#target-data-source) of epiweekly incident COVID-19 hospital admissions reported to NHSN.


### `methods`

A brief description of your forecasting methodology. Must be fewer than 200 characters.

### `methods_long`

A full description of your model methods. If the model is modified, you can use this field to provide a changelog, with dates and descriptions of implemented changes.


### `ensemble_of_models`

A boolean value (`true` or `false`) that indicates whether a model is an ensemble of any separate component models.

### `ensemble_of_hub_models`

A boolean value (`true` or `false`) that indicates whether a model is an ensemble specifically of other models submited to the FluSight forecasting hub.

## Optional fields
The following metadata fields are optional, but encouraged.

### `model_version`
An identifier of the version of the model. We recommend [semantic versioning](https://semver.org/) style: `X.Y` or `X.Y.Z`, so `1.2` for version 1.2.

### `website_url`

The url of a website with additional information about your model, such as detailed methods, visualizations, or interactive dashboards.

### `repo_url`

The URL of a Github (or similar) code repository containing model source code. 

### `citation`

Citations for one or more publications, preprints, et cetera with additional model details. Example: 
```
citation: "Gibson GC , Reich NG , Sheldon D. Real-time mechanistic bayesian forecasts of Covid-19 mortality. medRxiv. 2020. https://doi.org/10.1101/2020.12.22.20248736".
```

### `team_funding`

Any information about funding source(s) for the team or members of the team that would be relevant to include in resulting COVID-19 Forecast Hub publications. Example:
```
team_funding: "National Institutes of General Medical Sciences (R01GM123456). The content is solely the responsibility of the authors and does not necessarily represent the official views of NIGMS."
```

### `designated_github_users`

GitHub user ids of team members who would be responsible for submitting forecasts as a pull request to the CovidHub repository. Only the pull request from users specified here can get merged automatically after validation. Example:
```
designated_github_users: [
  "dependabot",
  "octocat"
]
```
or 
```
designated_github_users: ["dependabot"]
```

# Metadata validation

Optionally, you may validate a model metadata file locally before submitting it to the hub in a pull request. Note that this is not required, since the validations will also run on the pull request, but it is encouraged. To run validations locally, follow these steps:

1. Create a fork of the `covid-forecast-hub-2024` repository and then clone the fork to your computer.
2. Create a draft of the model metadata file for your model and place it in the `model-metadata` folder of this clone.
3. Install the hubValidations package for R by running the following command from within an R session:
``` r
install.packages("hubValidations", repos = c("https://hubverse-org.r-universe.dev", "https://cloud.r-project.org"))
```
4. Validate your draft metadata file by running the following command in an R session:
``` r
hubValidations::validate_model_metadata(
    hub_path="<path to your clone of the hub repository>",
    file_path="<name of your metadata file>")
```

For example, if your working directory is the root of the hub repository, you can use a command similar to the following:
``` r
hubValidations::validate_model_metadata(hub_path=".", file_path="UMass-trends_ensemble.yml")
```

If all is well, you should see output similar to the following:
```
✔ model-metadata-schema.json: File exists at path hub-config/model-metadata-schema.json.
✔ UMass-trends_ensemble.yml: File exists at path model-metadata/UMass-trends_ensemble.yml.
✔ UMass-trends_ensemble.yml: Metadata file extension is "yml" or "yaml".
✔ UMass-trends_ensemble.yml: Metadata file directory name matches "model-metadata".
✔ UMass-trends_ensemble.yml: Metadata file contents are consistent with schema specifications.
✔ UMass-trends_ensemble.yml: Metadata file name matches the `model_id` specified within the metadata file.
```

If there are any errors, you will see a message describing the problem.
