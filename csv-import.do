log using ///
	"E:\CSTOR_Research\Projects\Jones\NTDB_Comorbidity\csv-import.smcl", ///
	replace
	
set more off
clear
local NTDBDIR "E:\CSTOR_Research\DataSet\NTDB"
local workingdir "E:\CSTOR_Research\Projects\Jones\NTDB_Comorbidity"

foreach year in 2011 2012 2013 2014 {
	local csvdir "`NTDBDIR'\\`year'\CSV"
	import delimited using "`csvdir'\rds_comorbid.csv", varnames(1) clear
	save "`workingdir'\comorbid-`year'.dta", replace
	import delimited using "`csvdir'\rds_facility.csv", varnames(1) clear
	// Some facilities files (2014) have duplicates
	duplicates drop
	save "`workingdir'\facility-`year'.dta", replace
	import delimited using "`csvdir'\rds_demo.csv", varnames(1) clear
	save "`workingdir'\demo-`year'.dta", replace
}

log close
