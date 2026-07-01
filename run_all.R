# =====================================================================
# run_all.R  —  reproduce the entire pipeline end to end.
#
# Usage (from project root):
#   "C:/Program Files/R/R-4.5.2/bin/Rscript.exe" run_all.R
#
# Prerequisites:
#   - data/raw/scopus_2015.csv ... scopus_2025.csv  (11 Scopus exports,
#     ALL exported with the SAME field selection incl. affiliations,
#     abstract and keywords)
#   - internet access for the OpenAlex pull in step 02 (cached to
#     data/raw/openalex_raw.rds; delete that file to force a fresh pull)
# =====================================================================

t0 <- Sys.time()
steps <- c(
  "R/01_import_scopus.R",   # Scopus import + merge + country tags
  "R/02_pull_openalex.R",   # OpenAlex validation corpus (cached)
  "R/03_concentration.R",   # performance + concentration (Scopus)
  "R/04_science_mapping.R", # collaboration / keywords / thematic map
  "R/05_validation.R"       # cross-DB validation + abstract_numbers
)

for (s in steps) {
  cat("\n==============================================================\n")
  cat(">>> Running", s, "\n")
  cat("==============================================================\n")
  source(s, echo = FALSE)
}

cat("\nPipeline complete in",
    round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min.\n")
cat("Figures -> outputs/figures/ | Tables -> outputs/tables/\n")
cat("Headline numbers -> outputs/tables/abstract_numbers.csv\n")
