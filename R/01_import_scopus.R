# =====================================================================
# 01_import_scopus.R
# Import & merge the year-wise Scopus CSV exports into one corpus.
# Output: data/processed/M_scopus.rds  (a bibliometrix data frame)
#
# Search strategy (run per-year in Scopus, only PUBYEAR bounds change):
#   TITLE ( "artificial intelligence" OR "machine learning" OR
#           "deep learning" OR "convolutional neural network" OR "radiomics" )
#   AND TITLE-ABS-KEY ( "radiology" OR "radiological" OR "radiograph" OR
#           "computed tomography" OR "magnetic resonance imaging" OR
#           "mammography" OR "medical imaging" OR "diagnostic imaging" OR
#           "interventional radiology" )
#   AND PUBYEAR > 2014 AND PUBYEAR < 2026
#   AND ( DOCTYPE ( ar ) OR DOCTYPE ( re ) ) AND LANGUAGE ( english )
# =====================================================================

suppressPackageStartupMessages({
  library(bibliometrix)
  library(tidyverse)
})

# ---- Paths (relative to project root) -------------------------------
raw_dir  <- "data/raw"
proc_dir <- "data/processed"
dir.create(proc_dir, showWarnings = FALSE, recursive = TRUE)

# ---- 1. Locate the Scopus CSVs --------------------------------------
# Filenames sort chronologically: scopus_2015.csv ... scopus_2025.csv
files <- sort(list.files(raw_dir, pattern = "^scopus_\\d{4}\\.csv$",
                         full.names = TRUE))

cat("Scopus CSV files found:", length(files), "\n")
print(basename(files))

# Flag any missing expected years (2015-2025) so coverage gaps are visible.
expected_years <- 2015:2025
found_years <- as.integer(str_extract(basename(files), "\\d{4}"))
missing_years <- setdiff(expected_years, found_years)
if (length(missing_years) > 0) {
  cat("\n!! WARNING: missing year file(s) for:",
      paste(missing_years, collapse = ", "), "\n")
}
stopifnot(length(files) > 0)

# ---- 2. Convert + merge into one corpus -----------------------------
# convert2df accepts a vector of files and row-binds them.
M_scopus <- convert2df(files, dbsource = "scopus", format = "csv")
cat("\nRecords after import (pre de-dup):", nrow(M_scopus), "\n")

# ---- 3. De-duplicate ------------------------------------------------
# Prefer DOI; fall back to a normalised title for records without a DOI.
n_before <- nrow(M_scopus)
M_scopus <- M_scopus %>%
  mutate(.dedup_key = dplyr::if_else(
    !is.na(DI) & DI != "", toupper(DI),
    str_squish(toupper(TI)))) %>%
  distinct(.dedup_key, .keep_all = TRUE) %>%
  select(-.dedup_key)
cat("Records after de-dup:", nrow(M_scopus),
    sprintf("(removed %d)\n", n_before - nrow(M_scopus)))

# ---- 4. Country metadata -------------------------------------------
# AU1_CO = corresponding-author country (one country / paper -> clean shares)
# AU_CO  = all author countries (fallback if AU1_CO is sparse)
M_scopus <- metaTagExtraction(M_scopus, Field = "AU1_CO")
M_scopus <- metaTagExtraction(M_scopus, Field = "AU_CO")

au1_cov <- mean(!is.na(M_scopus$AU1_CO) & M_scopus$AU1_CO != "")
au_cov  <- mean(!is.na(M_scopus$AU_CO)  & M_scopus$AU_CO  != "")

# ---- 5. Quick diagnostics -------------------------------------------
yr <- suppressWarnings(as.integer(M_scopus$PY))
cat("\n================ IMPORT SUMMARY (Scopus) ================\n")
cat("Total records      :", nrow(M_scopus), "\n")
cat("Year range         :", min(yr, na.rm = TRUE), "-", max(yr, na.rm = TRUE), "\n")
cat("AU1_CO coverage    :", sprintf("%.1f%%", 100 * au1_cov),
    "(corresponding-author country)\n")
cat("AU_CO  coverage    :", sprintf("%.1f%%", 100 * au_cov),
    "(any-author country)\n")
cat("Records per year:\n")
print(as.data.frame(table(PY = yr), responseName = "n"))
cat("=========================================================\n")

# ---- 6. Save --------------------------------------------------------
saveRDS(M_scopus, file.path(proc_dir, "M_scopus.rds"))
cat("\nSaved -> data/processed/M_scopus.rds\n")
