log using ///
	"E:\CSTOR_Research\Projects\Jones\NTDB_Comorbidity\database-build.smcl", ///
	replace
	
set more off
clear

local workingdir "E:\CSTOR_Research\Projects\Jones\NTDB_Comorbidity"
local datafile "`workingdir'\database.dta"

gen inc_year=.

foreach year in 2011 2012 2013 2014 {
	append using "`workingdir'\comorbid-`year'.dta"
	drop comordes
	replace inc_year=`year' if inc_year == .
}

gen subsort=.
bysort inc_key : replace subsort=_n

reshape wide comorkey, i(inc_key inc_year) j(subsort)
keep inc_key inc_year comorkey1
// we now have incident, the year it occurred, and a single comorbidity variable
// comorkey1 is -1 if facility noted that pt had no comorbidities
// comorkey1 is -2 if facility did not report on pt
// comorkey1 is >0 if at least 1 comorbidity was listed, but the specific
// 		value is otherwise meaningless

foreach year in 2011 2012 2013 2014 {
	merge 1:1 inc_key using `workingdir'\demo-`year'.dta, ///
		keepusing(fac_key) update nogenerate
}

// calculate numbers with bysort facility inc_year:, drop all observations except
// one with bysort facility:, then drop inc_key comorkey1
// maybe do all with bysort facility inc_year?
bysort fac_key inc_year : egen year_incidents = total(fac_key != .)
bysort fac_key inc_year : egen year_missing = total(comorkey1 == -2)
bysort fac_key inc_year : egen year_nocomor = total(comorkey1 == -1)
bysort fac_key inc_year : egen year_comors = total(comorkey1 > 0)
bysort fac_key inc_year : drop if _n < _N
drop inc_key comorkey1

local facvars_s "hosptype teachsta acslevel statelev bedsize comorcd region"
local facvars_g "trcerreg tramreg traumsur"
local facvars "`facvars_s' `facvars_g'"
foreach var in `facvars_s' {
	gen `var'=""
} 
foreach var in `facvars_g' {
	gen `var'_cat=""
}
foreach year in 2014 2013 {
	merge m:1 fac_key using "`workingdir'\facility-`year'.dta", ///
		update nogenerate
	replace inc_year=`year' if inc_year==.
	foreach var of varlist `facvars' {
		replace `var'="" if inc_year < `year'
	}
}
foreach var of varlist `facvars_g' {
	replace `var'_cat=`var'
	drop `var'
	gen `var'=.
}
foreach year in 2012 2011 {
	merge m:1 fac_key using "`workingdir'\facility-`year'.dta", ///
		update nogenerate force
	foreach var of varlist `facvars_s' {
		replace `var'="" if inc_year < `year'
	}
	foreach var of varlist `facvars_g' {
		replace `var'=. if inc_year < `year'
	}
}

keep fac_key `facvars' year_* inc_year *_cat

gen acsverified="Yes" if acslevel != "" & acslevel != "Not Applicable" 
replace acsverified="No" if acslevel == "Not Applicable"

gen stateverified="Yes" if statelev != "Not Applicable" & statelev != ""
replace stateverified="No" if statelev == "Not Applicable"

gen trauma_center="Yes" if stateverified=="Yes" | acsverified=="Yes"
replace trauma_center="No" if stateverified=="No" & acsverified=="No"

gen traumalev=">III" if trauma_center=="Yes"
replace traumalev="III" if statelev=="III" | acslevel=="III"
replace traumalev="II" if statelev=="II" | acslevel=="II"
replace traumalev="I" if statelev=="I" | acslevel=="I"
replace traumalev="Not Applicable" if trauma_center=="No"

replace region="" if region=="NA"

// translate those facvars_g into appropriate 2013/2014 categories
// note that some information is lost (such as 0.5 FTE trauma registrars)
replace tramreg_cat="0" if tramreg_cat=="" & tramreg==0
replace tramreg_cat="1" if tramreg_cat=="" & tramreg==1
replace tramreg_cat=">1" if tramreg_cat=="" & tramreg > 1 & tramreg < .
replace tramreg_cat="" if tramreg_cat=="Not Known/Not Record"

replace trcerreg_cat="0" if trcerreg_cat=="" & trcerreg==0
replace trcerreg_cat="1" if trcerreg_cat=="" & trcerreg==1
replace trcerreg_cat=">1" if trcerreg_cat=="" & trcerreg > 1 & trcerreg < .

replace traumsur_cat="0" if traumsur_cat=="" & traumsur==0
replace traumsur_cat="1-3" if traumsur_cat=="" & traumsur >= 1 & ///
	traumsur <= 3
replace traumsur_cat="4-5" if traumsur_cat=="" & traumsur >= 4 & ///
	traumsur <= 5
replace traumsur_cat="5-6" if traumsur_cat=="" & traumsur > 5 & ///
	traumsur <= 6
replace traumsur_cat="7-8" if traumsur_cat=="" & traumsur >= 7 & ///
	traumsur <= 8
replace traumsur_cat=">8" if traumsur_cat=="" & traumsur > 8 & traumsur < .

gen year_pctmissing = year_missing / year_incidents

/// there are just a few facilities with no incidents; they thus have
/// missing data and are excluded automatically

bysort fac_key : egen years_contributing = total(comorcd != "Not collected")

foreach string in incidents missing nocomor comors {
	bysort fac_key : egen temp_`string' = total(year_`string') if ///
		comorcd != "Not collected"
	bysort fac_key : egen overall_`string' = max(temp_`string')
	drop temp_`string'
}

gen overall_pctmissing = overall_missing / overall_incidents

foreach var in hosptype teachsta acslevel statelev bedsize comorcd /// 
	region acsverified stateverified trauma_center traumalev ///
	traumsur_cat tramreg_cat trcerreg_cat {
		bysort fac_key : egen overall_`var' = mode(`var'), maxmode
}
foreach var in year_incidents traumsur tramreg trcerreg {
	bysort fac_key : egen overall_`var' = mean(`var')
}
save `datafile', replace

log close
