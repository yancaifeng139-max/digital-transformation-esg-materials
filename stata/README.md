# Stata Code for the Empirical Analyses

This folder contains the Stata code corresponding to the reported empirical analyses in the manuscript and appendix. The repository does not contain firm-level data.

## Files and running order

1. `00_config.do`: set the local project path, load the licensed analysis-ready data, apply the sample restrictions, and create the core quadratic terms.
2. `01_main_analyses.do`: reproduce the analyses reported in Sections 4--6 of the manuscript.
3. `02_appendix_analyses.do`: reproduce the reported empirical analyses in Appendices V--XV.

Run the files in that order after replacing `CHANGE_TO_YOUR_LOCAL_REPOSITORY_PATH` in `00_config.do`.

## Data availability

The data underlying the analyses are drawn from the licensed CNRDS and CSMAR databases and are not distributed in this repository. Researchers with authorised access must construct an analysis-ready firm-year data set using the variable definitions in the manuscript and appendix.

The analysis-ready file, named `analysis_data.dta` in the code, must contain the identifiers `Symbol` and `year`, the industry code `IndustryCode1`, the outcome variables, the controls, and the additional variables used in the individual reported analyses (for example, the external IV, network measures, analyst-attention measures, and data-asset disclosure frequency).

## Stata packages

The scripts use the following user-written packages: `reghdfe`, `ftools`, `ivreghdfe`, `ivreg2`, `ranktest`, `winsor2`, `estout`, `utest`, `psmatch2`, `pstest`, `ddml`, and `lassopack`.

The digital-technology dictionary, LDA topic outputs, patent-classification rules, and the Python code for constructing the patent-based digital-transformation measure are provided elsewhere in the repository.
