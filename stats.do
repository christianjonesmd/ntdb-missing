log using "E:\CSTOR_Research\Projects\Jones\NTDB_Comorbidity\stats.smcl", ///
	replace
set more off
use "E:\CSTOR_Research\Projects\Jones\NTDB_Comorbidity\database.dta", clear

local indep_cont_vars "year_incidents trcerreg tramreg traumsur"
local indep_cat_vars "trcerreg_cat tramreg_cat traumsur_cat hosptype teachsta"
local indep_cat_vars "`indep_cat_vars' bedsize comorcd region"
local indep_cat_vars "`indep_cat_vars' trauma_center traumalev" 
local indep_cat_vars "`indep_cat_vars' acsverified acslevel"
local indep_cat_vars "`indep_cat_vars' stateverified statelev"


foreach year in 2011 2012 2013 2014 {
	display "YEAR: `year'"
	display "Centers: "
	count if inc_year==`year'
	display "Centers reporting comorbidities not collected:"
	count if inc_year==`year' & comorcd == "Not collected"
	tabstat year_missing year_incidents if inc_year==`year' & ///
		comorcd != "Not collected", stat(sum)
	summarize year_pctmissing ///
		if inc_year==`year' & comorcd != "Not collected", detail
	display "Centers reporting no missing data:"
	count if year_pctmissing == 0 & inc_year==`year' & ///
		comorcd != "Not collected"
	display "Centers reporting only missing data:"
	count if year_pctmissing == 1 & inc_year==`year' & ///
		comorcd != "Not collected"
	foreach var in `indep_cont_vars' {
		display "Percent missing by (continuous) `var'"
		spearman year_pctmissing `var' if ///
			inc_year==`year' & comorcd != "Not collected", ///
			stats(obs p)
	}
	foreach var in `indep_cat_vars' {
		display "Percent missing by `var'"
		levelsof `var' if comorcd != "Not collected" & inc_year==`year', ///
			local(levels)
		foreach level of local levels {
			display "`var' = `level':"
			mean year_pctmissing if comorcd != "Not collected" & ///
				inc_year==`year' & `var'=="`level'"
		}
		kwallis year_pctmissing if ///
			inc_year==`year' & comorcd != "Not collected", ///
			by(`var')
	}
	display "Percent missing by level 1 vs level 2:"
	kwallis year_pctmissing if ///
		inc_year==`year' & comorcd != "Not collected" & ///
		(acslevel == "I" | acslevel == "II"), ///
		by(acslevel)
	kwallis year_pctmissing if ///
		inc_year==`year' & comorcd != "Not collected" & ///
		(statelev == "I" | statelev == "II"), ///
		by(statelev)
	kwallis year_pctmissing if ///
		inc_year==`year' & comorcd != "Not collected" & ///
		(traumalev == "I" | traumalev == "II"), ///
		by(traumalev)
}

display "OVERALL"
display "Total centers:"
unique fac_key
display "Centers reporting comorbidities at least one year:"
unique fac_key if years_contributing != 0
bysort fac_key : drop if _n != 1
drop if years_contributing == 0

tabstat overall_missing overall_incidents, stat(sum)
summarize overall_pctmissing, detail
display "Centers reporting no missing data:"
count if overall_pctmissing == 0
display "Centers reporting only missing data:"
count if overall_pctmissing == 1
foreach var in `indep_cont_vars' {
	display "Percent missing by (continuous) overall_`var'"
	spearman overall_pctmissing overall_`var', ///
			stats(obs p)
	}
	foreach var in `indep_cat_vars' {
		display "Percent missing by overall_`var'"
		levelsof overall_`var', local(levels)
		foreach level of local levels {
			display "overall_`var' = `level':"
			mean overall_pctmissing if overall_`var'=="`level'"
		}
		kwallis overall_pctmissing, by(overall_`var')
	}
	// fix comorcd to exclude those centers who mostly didn't submit
	kwallis overall_pctmissing if overall_comorcd!="Not collected", ///
		by(overall_comorcd)
	display "Percent missing by level 1 vs level 2:"
	kwallis overall_pctmissing if ///
		(overall_acslevel == "I" | overall_acslevel == "II"), ///
		by(overall_acslevel)
	kwallis overall_pctmissing if ///
		(overall_statelev == "I" | overall_statelev == "II"), ///
		by(overall_statelev)
	kwallis overall_pctmissing if ///
		(overall_traumalev == "I" | overall_traumalev == "II"), ///
		by(overall_traumalev)

/// multivariable
foreach var in teachsta bedsize region trauma_center traumalev acslevel ///
	stateverified statelev {
	encode overall_`var', generate(overall_`var'_c)
}

anova overall_pctmissing c.overall_year_incidents c.overall_tramreg ///
	c.overall_traumsur ib3.overall_teachsta_c ib3.overall_bedsize_c ///
	i.overall_region_c i.overall_acslevel_c i.overall_statelev_c
margins, dydx(*)	
	
cumul overall_pctmissing, generate(cdf)
sort cdf
generate est_slope=((cdf[_n+5]+cdf[_n+4]+cdf[_n+3]+cdf[_n+2]+cdf[_n+1] ///
	-cdf[_n-1]-cdf[_n-2]-cdf[_n-3]-cdf[_n-4]-cdf[_n-5])/5) / ///
	((overall_pctmissing[_n+5]+overall_pctmissing[_n+4]+ ///
	overall_pctmissing[_n+3]+overall_pctmissing[_n+2]+ ///
	overall_pctmissing[_n+1]-overall_pctmissing[_n-1]- ///
	overall_pctmissing[_n-2]-overall_pctmissing[_n-3]- ///
	overall_pctmissing[_n-4]-overall_pctmissing[_n-5])/5)
list overall_pctmissing est_slope if est_slope < 1.1 & est_slope > 0.9

tabstat overall_missing if overall_pctmissing > 0.05, stat(sum)
tabstat overall_missing, stat(sum)
count if overall_pctmissing > 0.05
count

// compare the two groups?

log close
