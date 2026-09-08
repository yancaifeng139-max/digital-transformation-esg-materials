/*
  Appendix empirical analyses
  Run 00_config.do and then 01_main_analyses.do before this file.
  This file follows Appendices V--XV. Appendices II--IV contain the
  lexicon, LDA outputs and patent-classification materials, which are
  provided separately from the Stata code.
*/

do "00_config.do"
log using "${log_dir}/02_appendix_analyses.log", replace text
use "${output_dir}/analysis_ready.dta", clear

quietly reghdfe ESG_Score digital digital_sq $CV, absorb(Symbol year) vce(cluster Symbol)
gen byte sample_main = e(sample)

* ================================================================
* Appendix V. VIF diagnostic
* ================================================================
reg ESG_Score digital digital_sq $CV if sample_main
estat vif

* ================================================================
* Appendix VI. Relative measure of digital patents (Table A12)
* ================================================================
capture drop digital_asset digital_asset_w digital_asset_w_sq
gen double digital_asset = digital_patents/(total_assets/1000000000) if total_assets > 0
winsor2 digital_asset, cuts(1 99) suffix(_w)
gen double digital_asset_w_sq = digital_asset_w^2
reghdfe ESG_Score digital_asset_w digital_asset_w_sq $CV, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store relative_measure

* ================================================================
* Appendix VII. One-period-lagged IV (Table A13)
* ================================================================
capture drop L1_digital L1_digital_sq sample_iv_lag
gen double L1_digital    = L1.digital
gen double L1_digital_sq = L1.digital_sq
reghdfe ESG_Score digital digital_sq $CV if sample_iv_lag, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store lag_iv_same_sample_ols
reghdfe digital L.digital L.digital_sq $CV, absorb(Symbol year) cluster(Symbol) 
estimates store lag_iv_first_stage_digital
reghdfe digital_sq L.digital L.digital_sq $CV, absorb(Symbol year) cluster(Symbol) 
estimates store lag_iv_first_stage_digital_sq
ivreghdfe ESG_Score $CV (digital digital_sq = L1_digital L1_digital_sq), ///
    absorb(Symbol year) cluster(Symbol) first
gen byte sample_iv_lag = e(sample)
estimates store lag_iv_second_stage

* ================================================================
* Appendix VIII. PSM balance/common-support plots
* (generated in 01_main_analyses.do; repeated here for stand-alone use)
* ================================================================
capture drop treat _treated _support _pscore _weight _id _nn
gen byte treat = (digital > 0) if !missing(digital)
psmatch2 treat $CV i.year i.industry_id if sample_main, ///
    logit kernel kerneltype(epan) bwidth(0.06) common
pstest $CV, both graph
graph export "${output_dir}/Figure_A1_PSM_balance.png", replace width(3000)
psgraph
graph export "${output_dir}/Figure_A2_PSM_common_support.png", replace width(3000)

* ================================================================
* Appendix IX. Fixed-sample diagnostics (Table A14)
* ================================================================
capture drop L2_digital L2_digital_sq F1_digital F1_digital_sq province_year
gen double L2_digital    = L2.digital
gen double L2_digital_sq = L2_digital^2
gen double F1_digital    = F1.digital
gen double F1_digital_sq = F1_digital^2
reghdfe ESG_Score L2_digital L2_digital_sq $CV, absorb(Symbol year) vce(cluster Symbol)
estimates store lag2
reghdfe ESG_Score digital digital_sq F1_digital F1_digital_sq $CV, ///
    absorb(Symbol year) vce(cluster Symbol)
test F1_digital F1_digital_sq
egen long province_year = group(PROVINCECODE year)
reghdfe ESG_Score digital digital_sq $CV, absorb(Symbol province_year) vce(cluster Symbol)
gen byte sample_province_year = e(sample)
reghdfe ESG_Score digital digital_sq $CV if sample_province_year, ///
    absorb(Symbol year) vce(cluster Symbol)

* ================================================================
* Appendix X. Network conditional prediction curves (Figure A3)
* ================================================================
* The regression table uses mean-centered variables. For Figure A3 only,
* the algebraically equivalent raw-scale specification below is estimated so
* that digital transformation and network centrality can be displayed in their
* original units. The specification retains all lower-order terms and thus
* yields the same fitted values as the centered Table 11 specification.
capture graph drop graph_outdegree
capture graph drop graph_indegree
capture graph drop graph_network
capture drop outdegree_plot indegree_plot

* Network coverage follows the Table 11 construction: missing centrality is
* coded as zero, and the two raw measures are winsorized at the 1st/99th pct.
clonevar outdegree_plot = weighted_out_degree
clonevar indegree_plot  = weighted_in_degree
replace outdegree_plot = 0 if sample_main & missing(outdegree_plot)
replace indegree_plot  = 0 if sample_main & missing(indegree_plot)
winsor2 outdegree_plot indegree_plot if sample_main, replace cuts(1 99)

* The raw digital-transformation support is [0, 5.209]. The 0--5.2 display
* range and 0.2 increment reproduce the submitted Appendix Figure A3.
local digital_min  = 0
local digital_max  = 5.2
local digital_step = 0.2

* Obtain the displayed P75 and P90 network-centrality values from the final
* estimation sample rather than relying on hard-coded numbers.
quietly summarize outdegree_plot if sample_main, detail
local out_p75 = r(p75)
local out_p90 = r(p90)
quietly summarize indegree_plot if sample_main, detail
local in_p75 = r(p75)
local in_p90 = r(p90)

graph set window fontface "Times New Roman"
graph set print  fontface "Times New Roman"

* Panel A. Weighted out-degree
reghdfe ESG_Score c.digital##c.digital##c.outdegree_plot $CV if sample_main, ///
    absorb(Symbol year) vce(cluster Symbol)

margins, at(digital=(`digital_min'(`digital_step')`digital_max') ///
    outdegree_plot=(0 `out_p75' `out_p90')) predict(xb)

marginsplot, xdimension(digital) plotdimension(outdegree_plot) recast(line) noci ///
    plot1opts(lcolor(navy) lpattern(shortdash) lwidth(medthick)) ///
    plot2opts(lcolor(forest_green) lpattern(solid) lwidth(medthick)) ///
    plot3opts(lcolor(maroon) lpattern(longdash) lwidth(medthick)) ///
    title("A. Weighted Out-degree", size(medsmall)) ///
    xtitle("Digital Transformation", size(small)) ///
    ytitle("Predicted ESG Score", size(small)) ///
    xscale(range(0 5.2)) xlabel(0(1)5, format(%3.0f) labsize(small) nogrid) ///
    yscale(range(26.5 29.2)) ylabel(26.5(0.5)29, angle(horizontal) ///
        format(%4.1f) labsize(small)) ///
    legend(order(1 "Low (0)" 2 "Medium (P75)" 3 "High (P90)") rows(1) ///
        size(vsmall) region(lcolor(none))) ///
    graphregion(color(white)) plotregion(color(white) margin(small)) ///
    name(graph_outdegree, replace)

* Panel B. Weighted in-degree
reghdfe ESG_Score c.digital##c.digital##c.indegree_plot $CV if sample_main, ///
    absorb(Symbol year) vce(cluster Symbol)

margins, at(digital=(`digital_min'(`digital_step')`digital_max') ///
    indegree_plot=(0 `in_p75' `in_p90')) predict(xb)

marginsplot, xdimension(digital) plotdimension(indegree_plot) recast(line) noci ///
    plot1opts(lcolor(navy) lpattern(shortdash) lwidth(medthick)) ///
    plot2opts(lcolor(forest_green) lpattern(solid) lwidth(medthick)) ///
    plot3opts(lcolor(maroon) lpattern(longdash) lwidth(medthick)) ///
    title("B. Weighted In-degree", size(medsmall)) ///
    xtitle("Digital Transformation", size(small)) ///
    ytitle("Predicted ESG Score", size(small)) ///
    xscale(range(0 5.2)) xlabel(0(1)5, format(%3.0f) labsize(small) nogrid) ///
    yscale(range(26.5 29.2)) ylabel(26.5(0.5)29, angle(horizontal) ///
        format(%4.1f) labsize(small)) ///
    legend(order(1 "Low (0)" 2 "Medium (P75)" 3 "High (P90)") rows(1) ///
        size(vsmall) region(lcolor(none))) ///
    graphregion(color(white)) plotregion(color(white) margin(small)) ///
    name(graph_indegree, replace)

graph combine graph_outdegree graph_indegree, cols(1) xcommon ycommon ///
    imargin(small) xsize(7) ysize(9) ///
    title("Conditional Prediction Curves by Network Centrality", size(medsmall)) ///
    note("Note: Low, medium, and high levels correspond to 0, P75, and P90, respectively." ///
         "Statistical inference is reported in Table 11.", size(vsmall)) ///
    graphregion(color(white)) name(graph_network, replace)

graph export "${output_dir}/Figure_A3_network_centrality.png", width(4000) replace


* ================================================================
* Appendix XI. Analyst-attention conditional curves (Figure A4;
* Tables A15--A17)
* ================================================================
* Table 12 uses mean-centered variables. To reproduce the submitted Figure
* A4 on raw scales, the equivalent raw-scale specifications below are used
* only for plotting. They include all lower-order terms and therefore yield
* the same fitted values as the corresponding centered specifications.
capture graph drop graph_ana_wfre
capture graph drop graph_ana_senw
capture graph drop graph_ana_attention
capture drop sample_ana
winsor2 wfre_ana senw_ana, replace cuts(1 99)
quietly reghdfe ESG_Score digital wfre_ana senw_ana $CV if sample_main, ///
    absorb(Symbol year) vce(cluster Symbol)
gen byte sample_ana = e(sample)

* Low, medium, and high levels are the raw P25, P50, and P75 values in the
* common 2015--2023 analyst-attention sample (N = 10,730).
quietly summarize wfre_ana if sample_ana, detail
local wfre_p25 = r(p25)
local wfre_p50 = r(p50)
local wfre_p75 = r(p75)
quietly summarize senw_ana if sample_ana, detail
local senw_p25 = r(p25)
local senw_p50 = r(p50)
local senw_p75 = r(p75)

graph set window fontface "Times New Roman"
graph set print  fontface "Times New Roman"
set scheme s1color

* Panel A. Keyword-frequency measure
reghdfe ESG_Score c.digital##c.digital##c.wfre_ana $CV if sample_ana, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store ana_wfre_plot

margins, at(digital=(0(0.1)5.2) ///
    wfre_ana=(`wfre_p25' `wfre_p50' `wfre_p75')) predict(xb)

marginsplot, xdimension(digital) plotdimension(wfre_ana) recast(line) noci ///
    plot1opts(lcolor(navy) lpattern(dash) lwidth(medthick)) ///
    plot2opts(lcolor(forest_green) lpattern(solid) lwidth(medthick)) ///
    plot3opts(lcolor(maroon) lpattern(longdash) lwidth(medthick)) ///
    title("A. Keyword-Frequency Measure", size(medsmall)) ///
    xtitle("Digital Transformation") ytitle("Predicted ESG Score") ///
    legend(order(1 "Low (P25)" 2 "Medium (P50)" 3 "High (P75)") ///
        rows(1) size(small)) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(graph_ana_wfre, replace)

* Panel B. Sentence-frequency measure
reghdfe ESG_Score c.digital##c.digital##c.senw_ana $CV if sample_ana, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store ana_senw_plot

margins, at(digital=(0(0.1)5.2) ///
    senw_ana=(`senw_p25' `senw_p50' `senw_p75')) predict(xb)

marginsplot, xdimension(digital) plotdimension(senw_ana) recast(line) noci ///
    plot1opts(lcolor(navy) lpattern(dash) lwidth(medthick)) ///
    plot2opts(lcolor(forest_green) lpattern(solid) lwidth(medthick)) ///
    plot3opts(lcolor(maroon) lpattern(longdash) lwidth(medthick)) ///
    title("B. Sentence-Frequency Measure", size(medsmall)) ///
    xtitle("Digital Transformation") ytitle("Predicted ESG Score") ///
    legend(order(1 "Low (P25)" 2 "Medium (P50)" 3 "High (P75)") ///
        rows(1) size(small)) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(graph_ana_senw, replace)

graph combine graph_ana_wfre graph_ana_senw, cols(1) xcommon ycommon ///
    imargin(tiny) graphregion(color(white)) ///
    title("Conditional Prediction Curves by Analyst Digital Attention", ///
        size(medium)) ///
    note("Notes: Low, medium, and high analyst digital attention correspond to the 25th," ///
         "50th, and 75th percentiles, respectively. Predictions are based on the models reported" ///
         "in Table 12.", size(vsmall)) ///
    name(graph_ana_attention, replace)

capture graph export "${output_dir}/Figure_A4_analyst_attention.emf", replace
graph export "${output_dir}/Figure_A4_analyst_attention.png", width(3000) replace


* ================================================================
* Appendix XII. U-shape tests by ESG dimension (Table A18)
* ================================================================
foreach outcome in E_Score S_Score G_Score {
    reghdfe `outcome' digital digital_sq $CV if sample_main, ///
        absorb(Symbol year) vce(cluster Symbol)
    quietly summarize digital if e(sample), detail
    utest digital digital_sq, min(`r(min)') max(`r(max)') quadratic fieller
}

* ================================================================
* Appendix XIII. Reconstructed disclosure--action deviation (Table A19)
* ================================================================
capture drop say_wufei saydo_gap high_gap
gen double say_wufei = dig
reghdfe say_wufei digital $CV if sample_main, absorb(Symbol year) ///
    vce(cluster Symbol) residuals(saydo_gap)
gen byte high_gap = (saydo_gap > 0) if !missing(saydo_gap)
reghdfe ESG_Score digital digital_sq $CV if high_gap == 0, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store action_at_least_as_high
reghdfe ESG_Score digital digital_sq $CV if high_gap == 1, ///
    absorb(Symbol year) vce(cluster Symbol)
estimates store disclosure_relatively_high
reghdfe ESG_Score c.digital c.digital_sq i.high_gap ///
    c.digital#i.high_gap c.digital_sq#i.high_gap $CV, ///
    absorb(Symbol year) vce(cluster Symbol)
test 1.high_gap#c.digital_sq
test 1.high_gap#c.digital 1.high_gap#c.digital_sq

* ================================================================
* Appendix XIV. Zero-valued observations (Tables A20--A21)
* ================================================================
capture drop digital_positive
gen byte digital_positive = (digital > 0) if !missing(digital)
reghdfe ESG_Score digital_positive digital digital_sq $CV if sample_main, ///
    absorb(Symbol year) vce(cluster Symbol)
nlcom (turning_point: -_b[digital]/(2*_b[digital_sq]))
reghdfe ESG_Score digital digital_sq $CV if sample_main & digital > 0, ///
    absorb(Symbol year) vce(cluster Symbol)
nlcom (turning_point: -_b[digital]/(2*_b[digital_sq]))

* ================================================================
* Appendix XV. Support structure and semiparametric diagnostic
* ================================================================
capture drop positive_group digital_group partial_ESG yhat digital_effect other_effect
xtile positive_group = digital if sample_main & digital > 0, nq(5)
gen byte digital_group = 0 if sample_main & digital == 0
replace digital_group = positive_group if sample_main & digital > 0
tabstat digital if sample_main, by(digital_group) stat(n min mean p50 max)

* Semiparametric fitted curve: Epanechnikov kernel, fourth-order local polynomial.
* The semiparametric FE estimator treats digital nonparametrically and
* includes the covariates and year indicators linearly.
capture drop year_fe_*
tabulate year if sample_main, generate(year_fe_)
xtsemipar ESG_Score $CV year_fe_2-year_fe_14 if sample_main, ///
    nonpar(digital) generate(nonpar_fit)

* The following plots display the net fitted relationship under the
* three bandwidth specifications reported in Appendix XV.
reghdfe ESG_Score c.digital##c.digital $CV if sample_main, absorb(Symbol year) vce(cluster Symbol)
predict double yhat if e(sample), xb
gen double digital_effect = _b[digital]*digital + _b[c.digital#c.digital]*digital^2 if e(sample)
gen double other_effect = yhat - digital_effect if e(sample)
gen double partial_ESG = ESG_Score - other_effect if e(sample)

foreach bw in 0.421 0.526 0.631 {
    lpoly partial_ESG digital if sample_main, degree(4) kernel(epan) bwidth(`bw') ci ///
        title("") xtitle("Digital transformation") ///
        ytitle("Net semiparametric relationship") graphregion(color(white))
    graph export "${output_dir}/Figure_A5_semiparametric_bw_`bw'.png", replace width(3000)
}

log close
