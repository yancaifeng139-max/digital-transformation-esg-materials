/*
  Configuration file for the Stata replication code
  -------------------------------------------------
  1. Change project_root to the folder containing this repository.
  2. Obtain the licensed source data independently from CNRDS/CSMAR.
  3. Prepare the analysis-ready file described in README.md and place it
     in /data. No proprietary data are included in this repository.
*/

version 18.0
clear all
set more off

* EDIT THIS PATH BEFORE RUNNING THE CODE
global project_root "CHANGE_TO_YOUR_LOCAL_REPOSITORY_PATH"

global data_dir   "${project_root}/data"
global output_dir "${project_root}/output"
global log_dir    "${project_root}/logs"

capture mkdir "${output_dir}"
capture mkdir "${log_dir}"

* Controls used throughout the empirical analysis
global CV "growth size lev cashflow fixed ret board dual top1 firmage"

* Required user-written commands: reghdfe, ftools, ivreghdfe, ivreg2,
* ranktest, winsor2, estout, utest, psmatch2, pstest, ddml, lassopack.

* The analysis-ready data file is not distributed with this repository.
use "${data_dir}/analysis_data.dta", clear

* The sample exclusions and transformations used in the manuscript
drop if inlist(substr(IndustryCode1, 1, 1), "J", "K")
winsor2 digital ESG_Score $CV, replace cuts(1 99)
capture drop digital_sq digital_cube industry_id
gen double digital_sq = digital^2
gen double digital_cube = digital^3
encode IndustryCode1, gen(industry_id)
xtset Symbol year

* Confirm that the squared term is generated from the final winsorized term.
assert abs(digital_sq - digital^2) < 1e-12 if !missing(digital, digital_sq)

save "${output_dir}/analysis_ready.dta", replace
