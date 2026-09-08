/*
  Main-text empirical analyses
  Run 00_config.do first. This file follows the order of Sections 4--6.
  It assumes that the licensed, analysis-ready data include all variables
  named below; see README.md for the required variables.
*/

do "00_config.do"
log using "${log_dir}/01_main_analyses.log", replace text

use "${output_dir}/analysis_ready.dta", clear

* ================================================================
* 4.1 Descriptive statistics and correlation analysis (Tables 3--4)
* ================================================================
quietly reghdfe ESG_Score digital digital_sq $CV, absorb(Symbol year) vce(cluster Symbol)
gen byte sample_main = e(sample)

summarize ESG_Score digital digital_sq $CV if sample_main, detail
pwcorr ESG_Score digital digital_sq $CV if sample_main, sig obs

* ================================================================
* 4.2 Baseline regression and inverted-U test (Tables 5--6; Figure 3)
* ================================================================
reghdfe ESG_Score digital $CV if sample_main, absorb(Symbol year) vce(cluster Symbol)
estimates store baseline_linear
reghdfe ESG_Score digital digital_sq if sample_main, absorb(Symbol year) vce(cluster Symbol)
estimates store baseline_quadratic_uncontrolled
reghdfe ESG_Score digital digital_sq $CV if sample_main, absorb(Symbol year) vce(cluster Symbol)
estimates store baseline_quadratic

utest digital digital_sq, fieller
nlcom (turning_point: -_b[digital] / (2 * _b[digital_sq]))

* Marginal-effect and fitted-curve figure
reghdfe ESG_Score c.digital##c.digital $CV if sample_main, absorb(Symbol year) vce(cluster Symbol)
margins, dydx(digital) at(digital=(0(0.1)5.209))
marginsplot, yline(0, lpattern(dash)) recast(line) recastci(rarea) ///
    title("") xtitle("Digital transformation") ytitle("Marginal effect") ///
    legend(off) graphregion(color(white))
graph export "${output_dir}/Figure_3a_marginal_effects.png", replace width(3000)

margins, at(digital=(0(0.1)5.209))
marginsplot, noci title("") xtitle("Digital transformation") ///
    ytitle("Predicted ESG score") legend(off) graphregion(color(white))
graph export "${output_dir}/Figure_3b_fitted_curve.png", replace width(3000)

* ================================================================
* 4.3 Robustness checks (Tables 7--8)
* ================================================================
* 4.3.1 Alternative digital-transformation measures
winsor2 dig dig_word dig_sen, replace cuts(1 99)
capture drop dig_sq dig_word_sq dig_sen_sq
gen double dig_sq      = dig^2
gen double dig_word_sq = dig_word^2
gen double dig_sen_sq  = dig_sen^2

reghdfe ESG_Score dig dig_sq $CV, absorb(Symbol year) vce(cluster Symbol)
estimates store alt_patent_measure
reghdfe ESG_Score dig_word dig_word_sq $CV, absorb(Symbol year) vce(cluster Symbol)
estimates store alt_mda_word_measure
reghdfe ESG_Score dig_sen dig_sen_sq $CV, absorb(Symbol year) vce(cluster Symbol)
estimates store alt_mda_sentence_measure

* 4.3.2 Cubic specification
reghdfe ESG_Score digital digital_sq digital_cube $CV if sample_main, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store cubic_specification

* 4.3.3 Industry-year fixed effects
reghdfe ESG_Score digital digital_sq $CV if sample_main, ///
    absorb(Symbol industry_id#year) vce(cluster Symbol)
estimates store industry_year_fe

* 4.3.4 Double machine learning (DML)
* FWL residualization of firm and year fixed effects, followed by DDML.
preserve
keep if sample_main
foreach v of varlist ESG_Score digital digital_sq $CV {
    quietly reghdfe `v', absorb(Symbol year) resid(r_`v')
}
local r_CV ""
foreach v of global CV {
    local r_CV "`r_CV' r_`v'"
}
set seed 20260904
capture ddml drop dml_main
ddml init partial, mname(dml_main) kfolds(5) fcluster(Symbol) reps(10)
ddml E[Y|X]: rlasso r_ESG_Score `r_CV', cluster(Symbol)
ddml E[D|X]: rlasso r_digital `r_CV', cluster(Symbol)
ddml E[D|X]: rlasso r_digital_sq `r_CV', cluster(Symbol)
ddml crossfit, mname(dml_main)
ddml estimate, mname(dml_main) cluster(Symbol)
restore

* ================================================================
* 4.4 Potential endogeneity concerns and mitigation (Tables 9--10)
* ================================================================
* 4.4.1 External instrumental-variable estimation.
* The analysis-ready data must contain iv and iv_sq: the historical
* telecommunications x lagged national Internet-use instrument and its square.
reghdfe ESG_Score digital digital_sq $CV if sample_main, absorb(Symbol year) vce(cluster Symbol)
estimates store ols_iv_sample
reghdfe digital iv iv_sq $CV if sample_main, absorb(Symbol year) vce(cluster Symbol)
estimates store iv_first_stage_digital
reghdfe digital_sq iv iv_sq $CV if sample_main, absorb(Symbol year) vce(cluster Symbol)
estimates store iv_first_stage_digital_sq
ivreghdfe ESG_Score $CV (digital digital_sq = iv iv_sq) if sample_main, ///
    absorb(Symbol year) cluster(Symbol) first
estimates store iv_second_stage

* 4.4.2 Propensity-score kernel matching
capture drop treat _treated _support _pscore _weight _id _nn psm_matched
gen byte treat = (digital > 0) if !missing(digital)
psmatch2 treat $CV i.year i.industry_id if sample_main, ///
    logit kernel kerneltype(epan) bwidth(0.06) common
pstest $CV, both graph
graph export "${output_dir}/Figure_A1_PSM_balance.png", replace width(3000)
psgraph
graph export "${output_dir}/Figure_A2_PSM_common_support.png", replace width(3000)
gen byte psm_matched = (_support == 1 & _weight > 0) if !missing(_support, _weight)
reghdfe ESG_Score digital digital_sq $CV [aw=_weight] if psm_matched, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store psm_kernel

* 4.4.3 Supplementary analyses: lags, lead placebo, and province-year FE
capture drop L1_digital L1_digital_sq L2_digital L2_digital_sq F1_digital F1_digital_sq province_year
gen double L1_digital    = L1.digital
gen double L1_digital_sq = L1_digital^2
gen double L2_digital    = L2.digital
gen double L2_digital_sq = L2_digital^2
gen double F1_digital    = F1.digital
gen double F1_digital_sq = F1_digital^2

reghdfe ESG_Score L1_digital L1_digital_sq $CV, absorb(Symbol year) vce(cluster Symbol)
estimates store lag1
reghdfe ESG_Score L2_digital L2_digital_sq $CV, absorb(Symbol year) vce(cluster Symbol)
estimates store lag2
reghdfe ESG_Score digital digital_sq F1_digital F1_digital_sq $CV, ///
    absorb(Symbol year) vce(cluster Symbol)
test F1_digital F1_digital_sq
estimates store lead_placebo
egen long province_year = group(PROVINCECODE year)
reghdfe ESG_Score digital digital_sq $CV, absorb(Symbol province_year) vce(cluster Symbol)
estimates store province_year_fe

* ================================================================
* 5. Moderating-effect analyses (Tables 11--12)
* ================================================================
* 5.1 Inter-firm technological innovation network
* Network variables are assigned zero when a firm-year has no observed
* patent-citation-network linkage, then winsorized and mean-centered.
capture drop digital_c outdegree indegree outdegree_c indegree_c
quietly summarize digital if sample_main, meanonly
gen double digital_c = digital - r(mean)
clonevar outdegree = weighted_out_degree
clonevar indegree  = weighted_in_degree
replace outdegree = 0 if sample_main & missing(outdegree)
replace indegree  = 0 if sample_main & missing(indegree)
winsor2 outdegree indegree if sample_main, replace cuts(1 99)
quietly summarize outdegree if sample_main, meanonly
gen double outdegree_c = outdegree - r(mean)
quietly summarize indegree if sample_main, meanonly
gen double indegree_c = indegree - r(mean)

reghdfe ESG_Score c.digital_c##c.digital_c##c.outdegree_c $CV ///
    if sample_main, absorb(Symbol year) vce(cluster Symbol)
estimates store network_outdegree
reghdfe ESG_Score c.digital_c##c.digital_c##c.indegree_c $CV ///
    if sample_main, absorb(Symbol year) vce(cluster Symbol)
estimates store network_indegree

* 5.2 Analyst digital attention (common available sample)
capture drop wfre_ana_c senw_ana_c sample_ana
winsor2 wfre_ana senw_ana, replace cuts(1 99)
quietly reghdfe ESG_Score digital wfre_ana senw_ana $CV if sample_main, ///
    absorb(Symbol year) vce(cluster Symbol)
gen byte sample_ana = e(sample)
quietly summarize wfre_ana if sample_ana, meanonly
gen double wfre_ana_c = wfre_ana - r(mean)
quietly summarize senw_ana if sample_ana, meanonly
gen double senw_ana_c = senw_ana - r(mean)

reghdfe ESG_Score c.digital_c##c.digital_c##c.wfre_ana_c $CV if sample_ana, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store attention_word_frequency
reghdfe ESG_Score c.digital_c##c.digital_c##c.senw_ana_c $CV absorb(Symbol year) vce(cluster Symbol)
estimates store attention_sentence_frequency

* ================================================================
* 6. Further analysis (Table 13)
* ================================================================
* 6.1 Data asset information disclosure
capture drop data_asset_disclosure
gen byte data_asset_disclosure = (lnTWFre > 0) if !missing(lnTWFre)
reghdfe ESG_Score digital digital_sq $CV if data_asset_disclosure == 1, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store disclosure_group
reghdfe ESG_Score digital digital_sq $CV if data_asset_disclosure == 0, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store nondisclosure_group
reghdfe ESG_Score ib0.data_asset_disclosure##(c.digital c.digital_sq) $CV, ///
    absorb(Symbol year) vce(cluster Symbol)
test 1.data_asset_disclosure#c.digital_sq
test 1.data_asset_disclosure#c.digital 1.data_asset_disclosure#c.digital_sq

* 6.2 ESG-dimension decomposition, standardized outcomes
capture drop ESG_z E_z S_z G_z
egen ESG_z = std(ESG_Score) if sample_main
egen E_z   = std(E_Score) if sample_main
egen S_z   = std(S_Score) if sample_main
egen G_z   = std(G_Score) if sample_main
foreach outcome in ESG_z E_z S_z G_z {
    reghdfe `outcome' digital digital_sq $CV if sample_main, ///
        absorb(Symbol year) vce(cluster Symbol)
    estimates store dim_`outcome'
}

log close
