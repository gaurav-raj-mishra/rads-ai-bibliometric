# =====================================================================
# 03_concentration.R
# CORE ANALYSIS on the primary (Scopus) corpus:
#   - performance: annual production, CAGR, top sources/institutions
#   - concentration: per-country shares, top-5 share, HHI, South Asia share
# Sources the reusable concentration() / performance_summary() from
# R/00_functions.R (also reused by 05_validation.R).
# Outputs -> outputs/tables/*.csv  and  data/processed/conc_scopus.rds
# =====================================================================

suppressPackageStartupMessages({
  library(bibliometrix)
  library(tidyverse)
})
source("R/00_functions.R")

proc_dir  <- "data/processed"
table_dir <- "outputs/tables"
dir.create(table_dir, showWarnings = FALSE, recursive = TRUE)

M_scopus <- readRDS(file.path(proc_dir, "M_scopus.rds"))

# ---- 1. Performance analysis ----------------------------------------
perf <- performance_summary(M_scopus)
cat("================ PERFORMANCE (Scopus) ================\n")
cat(sprintf("Total records : %d\n", perf$n_total))
cat(sprintf("Year range    : %d - %d\n", perf$year_range[1], perf$year_range[2]))
cat(sprintf("CAGR          : %.1f%% per year\n", 100 * perf$cagr))
cat("Annual production:\n"); print(perf$annual)

write_csv(perf$annual,      file.path(table_dir, "annual_production_scopus.csv"))
write_csv(perf$top_sources, file.path(table_dir, "top_sources_scopus.csv"))
if (!is.null(perf$top_inst))
  write_csv(perf$top_inst,  file.path(table_dir, "top_institutions_scopus.csv"))

# ---- 2. Concentration (headline) ------------------------------------
# Scopus AU1_CO labels are country NAMES (e.g. "CHINA") -> "country.name".
conc <- concentration(M_scopus, origin = "country.name", label = "Scopus")
print_concentration(conc)

write_csv(conc$shares, file.path(table_dir, "country_shares_scopus.csv"))
saveRDS(conc, file.path(proc_dir, "conc_scopus.rds"))

# Headline summary line for quick reference.
hl <- tibble(
  corpus            = "Scopus",
  n_total           = conc$n_total,
  n_with_country    = conc$n_with_country,
  country_field     = conc$country_field,
  top5_share_pct    = round(100 * conc$top5_share, 1),
  hhi               = round(conc$hhi, 4),
  south_asia_pct    = round(100 * conc$south_asia_share, 2),
  cagr_pct          = round(100 * perf$cagr, 1)
)
write_csv(hl, file.path(table_dir, "headline_scopus.csv"))
cat("\nSaved tables -> outputs/tables/  and  data/processed/conc_scopus.rds\n")
