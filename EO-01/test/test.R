#!/usr/bin/env Rscript

args = commandArgs(trailingOnly=TRUE)


if (length(args) != 3) {
  stop("\ngive input directory (mosaic) as 1st arg\ngive reference image (*.RData) as 2nd arg\ngive output file (*.txt) as 3rd arg", call.=FALSE)
}

dinp <- args[1]
fref <- args[2]
fout <- args[3]


# load package
require(raster)

res      <- 30
area_m2  <- res*res
area_km2 <- area_m2/1e6

tol      <- 2.5


# LOAD REFERENCE
#######################################################################
load(fref)


# WOODY COVER CHANGE
#######################################################################

fname <- dir(dinp, "HL_TSA_LNDLG_SMA_VBL-CAO.vrt$", full.names=TRUE)

wood_change <- raster(fname, band=1)[]

wood_total_off   <- raster(fname, band=5)[]
wood_total_gain  <- raster(fname, band=7)[]/1000
wood_total_sig   <- raster(fname, band=9)[]

wood_before_off  <- raster(fname, band=15)[]
wood_before_gain <- raster(fname, band=17)[]/1000
wood_before_sig  <- raster(fname, band=19)[]

wood_after_off   <- raster(fname, band=25)[]
wood_after_gain  <- raster(fname, band=27)[]/1000
wood_after_sig   <- raster(fname, band=29)[]

wood_abs_gain_total  <- wood_total_gain *wood_total_off /10000 # gain as fraction -1 to 0 or 0 to 1
wood_abs_gain_before <- wood_before_gain*wood_before_off/10000 # gain as fraction -1 to 0 or 0 to 1
wood_abs_gain_after  <- wood_after_gain *wood_after_off /10000 # gain as fraction -1 to 0 or 0 to 1

wood_rchange <- (wood_change/wood_total_off*100)*(wood_total_off>2500)

wood_event   <- (wood_rchange>=25)
wood_extract <- (wood_rchange>=25 & wood_rchange<50)*10
wood_remove  <- (wood_rchange>=50)*100

wood_abs_gain <- rep(0, length(wood_change))
wood_abs_gain <- wood_abs_gain -   wood_event  * wood_change/10000    # removal through event
wood_abs_gain <- wood_abs_gain +   wood_event  * wood_abs_gain_before # gradual change before event
wood_abs_gain <- wood_abs_gain +   wood_event  * wood_abs_gain_after  # gradual change after  event
wood_abs_gain <- wood_abs_gain + (!wood_event) * wood_abs_gain_total  # gradual change no event

wood_trend <- (!wood_event)*wood_total_sig + wood_event*wood_after_sig

wood_syndrome <- wood_extract+wood_remove+wood_trend

wood_abs_gain_m2  <- wood_abs_gain*area_m2
wood_abs_gain_m2_per_category <- split(wood_abs_gain_m2, wood_syndrome)

class_wood <- c(
"steady decrease",
"stable",
"steady increase",
"mildly disturbed, then decrease",
"mildly disturbed, then stable",
"mildly disturbed, then increase",
"severely disturbed, then decrease",
"severely disturbed, then stable",
"severely disturbed, then increase"
)
n_wood <- length(class_wood)
wood_id <- c(-1,0,1,9,10,11,99,100,101)



# HERBACEOUS COVER CHANGE
#######################################################################

fname <- dir(dinp, "HL_TSA_LNDLG_SMA_VSA-CAO.vrt$", full.names=TRUE)

herb_total_sig  <- raster(fname, band=9)[]
herb_total_off  <- raster(fname, band=5)[]
herb_total_gain <- raster(fname, band=7)[]/1000

herb_syndrome <- herb_total_sig

herb_abs_gain <- herb_total_gain*herb_total_off/10000 # gain as fraction -1 to 0 or 0 to 1

herb_abs_gain_m2  <- herb_abs_gain*area_m2
herb_abs_gain_m2_per_category <- split(herb_abs_gain_m2, herb_syndrome)

class_herb <- c(
"steady decrease",
"stable",
"steady increase"
)
n_herb <- length(class_herb)
herb_id <- c(-1,0,1)


tab_wood_syndrome <- table(wood_syndrome)*area_km2
names(tab_wood_syndrome) <- class_wood
tab_herb_syndrome <- table(herb_syndrome)*area_km2
names(tab_herb_syndrome) <- class_herb


tab_wood_abs_gain <- sapply(wood_abs_gain_m2_per_category, sum, na.rm=TRUE)/1e6
names(tab_wood_abs_gain) <- class_wood
tab_herb_abs_gain <- sapply(herb_abs_gain_m2_per_category, sum, na.rm=TRUE)/1e6
names(tab_herb_abs_gain) <- class_herb



# FOR REFERENCE: SAVE IMAGE
#######################################################################

#del <- ls()
#tab_wood_syndrome_ref <-  tab_wood_syndrome
#tab_herb_syndrome_ref <-  tab_herb_syndrome
#tab_wood_abs_gain_ref <-  tab_wood_abs_gain
#tab_herb_abs_gain_ref <-  tab_herb_abs_gain
#rm(list=del)
#rm(del)
#save.image(fref)

# COMPARE TESTRUN WITH REFERENCE EXECUTION
#######################################################################

cmp_wood_syndrome <- cbind(tab_wood_syndrome_ref, tab_wood_syndrome, tab_wood_syndrome-tab_wood_syndrome_ref, (tab_wood_syndrome-tab_wood_syndrome_ref)/tab_wood_syndrome_ref*100)
cmp_herb_syndrome <- cbind(tab_herb_syndrome_ref, tab_herb_syndrome, tab_herb_syndrome-tab_herb_syndrome_ref, (tab_herb_syndrome-tab_herb_syndrome_ref)/tab_herb_syndrome_ref*100)
cmp_wood_abs_gain <- cbind(tab_wood_abs_gain_ref, tab_wood_abs_gain, tab_wood_abs_gain-tab_wood_abs_gain_ref, (tab_wood_abs_gain-tab_wood_abs_gain_ref)/tab_wood_abs_gain_ref*100)
cmp_herb_abs_gain <- cbind(tab_herb_abs_gain_ref, tab_herb_abs_gain, tab_herb_abs_gain-tab_herb_abs_gain_ref, (tab_herb_abs_gain-tab_herb_abs_gain_ref)/tab_herb_abs_gain_ref*100)

total_diff_wood_syndrome <- mean(abs(cmp_wood_syndrome[,4]))
total_diff_herb_syndrome <- mean(abs(cmp_herb_syndrome[,4]))
total_diff_wood_abs_gain <- mean(abs(cmp_wood_abs_gain[,4]))
total_diff_herb_abs_gain <- mean(abs(cmp_herb_abs_gain[,4]))

log_wood_syndrome <- sprintf("% 33s % 14.2f % 14.2f % +14.2f  % +12.2f%%", class_wood, cmp_wood_syndrome[,1], cmp_wood_syndrome[,2], cmp_wood_syndrome[,3], cmp_wood_syndrome[,4])
log_herb_syndrome <- sprintf("% 33s % 14.2f % 14.2f % +14.2f  % +12.2f%%", class_herb, cmp_herb_syndrome[,1], cmp_herb_syndrome[,2], cmp_herb_syndrome[,3], cmp_herb_syndrome[,4])
log_wood_abs_gain <- sprintf("% 33s % 14.2f % 14.2f % +14.2f  % +12.2f%%", class_wood, cmp_wood_abs_gain[,1], cmp_wood_abs_gain[,2], cmp_wood_abs_gain[,3], cmp_wood_abs_gain[,4])
log_herb_abs_gain <- sprintf("% 33s % 14.2f % 14.2f % +14.2f  % +12.2f%%", class_herb, cmp_herb_abs_gain[,1], cmp_herb_abs_gain[,2], cmp_herb_abs_gain[,3], cmp_herb_abs_gain[,4])

header <- sprintf("% 33s % 14s % 14s % 14s % 14s", "syndrome", "area_reference", "area_current", "area_diff", "percent_diff")

log_wood_syndrome <- c(header, log_wood_syndrome)
log_herb_syndrome <- c(header, log_herb_syndrome)
log_wood_abs_gain <- c(header, log_wood_abs_gain)
log_herb_abs_gain <- c(header, log_herb_abs_gain)

dash <- paste(rep("-", 33+14*4+4), collapse="")

write("Test results for EO-01", fout)

write("\nArea [km²] affected by a woody vegetation syndrome:", fout, append=TRUE)
write(sprintf("Mean abs percent difference: %+.2f%%", total_diff_wood_syndrome), fout, append=TRUE)
write(dash, fout, append=TRUE)
write(log_wood_syndrome, fout, append=TRUE)

write("\nArea [km²] affected by a herbaceous vegetation syndrome:", fout, append=TRUE)
write(sprintf("Mean abs percent difference: %+.2f%%", total_diff_herb_syndrome), fout, append=TRUE)
write(dash, fout, append=TRUE)
write(log_herb_syndrome, fout, append=TRUE)

write("\nAbsolute cover [km²] lost/gained by a woody vegetation syndrome:", fout, append=TRUE)
write(sprintf("Mean abs percent difference: %+.2f%%", total_diff_wood_abs_gain), fout, append=TRUE)
write(dash, fout, append=TRUE)
write(log_wood_abs_gain, fout, append=TRUE)

write("\nAbsolute cover [km²] lost/gained by a herbaceous vegetation syndrome:", fout, append=TRUE)
write(sprintf("Mean abs percent difference: %+.2f%%", total_diff_herb_abs_gain), fout, append=TRUE)
write(dash, fout, append=TRUE)
write(log_herb_abs_gain, fout, append=TRUE)


# THROW ERROR IF REFERENCE DOES NOT MATCH
#######################################################################

if (total_diff_wood_syndrome > tol) stop("Area [km²] affected by a woody vegetation syndrome deviates from reference execution: mean abs percentage difference ", round(total_diff_wood_syndrome, 2))
if (total_diff_herb_syndrome > tol) stop("Area [km²] affected by a herbaceous vegetation syndrome deviates from reference execution: mean abs percentage difference ", round(total_diff_herb_syndrome, 2))
if (total_diff_wood_abs_gain > tol) stop("Absolute cover [km²] lost/gained by a woody vegetation syndrome deviates from reference execution: mean abs percentage difference ", round(total_diff_wood_abs_gain, 2))
if (total_diff_herb_abs_gain > tol) stop("Absolute cover [km²] lost/gained by a herbaceous vegetation syndrome deviates from reference execution: mean abs percentage difference ", round(total_diff_herb_abs_gain, 2))
  