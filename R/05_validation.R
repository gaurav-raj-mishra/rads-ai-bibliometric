# =====================================================================
# 05_validation.R
# CROSS-DATABASE VALIDATION (Scopus primary vs OpenAlex validation):
#   - run concentration() on both corpora
#   - side-by-side table: n, top-5 share, HHI, South Asia share
#   - Spearman correlation of per-country shares (full-join, zero-fill)
#   - assemble outputs/tables/abstract_numbers.csv  (every figure the
#     250-word abstract will cite)
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
M_oa     <- readRDS(file.path(proc_dir, "M_oa.rds"))

# ---- 1. Concentration on both ---------------------------------------
# Scopus AU1_CO = country NAMES; OpenAlex AU1_CO = ISO-2 codes (set in 02).
conc_s  <- concentration(M_scopus, origin = "country.name", label = "Scopus")
conc_oa <- concentration(M_oa,     origin = "iso2c",        label = "OpenAlex")
print_concentration(conc_s)
print_concentration(conc_oa)

# ---- 2. Side-by-side comparison table -------------------------------
comp <- tibble(
  metric   = c("N records", "N with country", "Top-5 share (%)",
               "HHI", "South Asia share (%)"),
  Scopus   = c(conc_s$n_total, conc_s$n_with_country,
               round(100 * conc_s$top5_share, 1), round(conc_s$hhi, 4),
               round(100 * conc_s$south_asia_share, 2)),
  OpenAlex = c(conc_oa$n_total, conc_oa$n_with_country,
               round(100 * conc_oa$top5_share, 1), round(conc_oa$hhi, 4),
               round(100 * conc_oa$south_asia_share, 2))
)
write_csv(comp, file.path(table_dir, "cross_db_comparison.csv"))
cat("\n================ CROSS-DB COMPARISON ================\n")
print(comp)

# ---- 3. Spearman correlation of per-country shares ------------------
j <- full_join(
  conc_s$shares  %>% select(iso3, s_scopus = share),
  conc_oa$shares %>% select(iso3, s_oa = share),
  by = "iso3") %>%
  mutate(s_scopus = replace_na(s_scopus, 0),
         s_oa     = replace_na(s_oa, 0))
rho <- cor(j$s_scopus, j$s_oa, method = "spearman")
write_csv(j, file.path(table_dir, "country_share_join.csv"))
cat(sprintf("\nSpearman rho (per-country shares, %d countries): %.3f\n", nrow(j), rho))

# Interpretation cues for the methods/results text.
interp <- sprintf(paste0(
  "Spearman rho = %.3f across %d countries. HHI Scopus = %.3f vs OpenAlex = %.3f. ",
  "High rho + similar HHI => the concentration pattern is robust across databases. ",
  "OpenAlex South Asia share (%.2f%%) vs Scopus (%.2f%%): %s."),
  rho, nrow(j), conc_s$hhi, conc_oa$hhi,
  100 * conc_oa$south_asia_share, 100 * conc_s$south_asia_share,
  ifelse(conc_oa$south_asia_share > conc_s$south_asia_share,
         "the higher OpenAlex share quantifies Scopus coverage bias against the region",
         "Scopus does not under-represent the region relative to OpenAlex"))
writeLines(interp, file.path(table_dir, "validation_interpretation.txt"))
cat(interp, "\n")

# ---- 4. Dominant thematic clusters (from 04 output) -----------------
theme_labels <- NA_character_
tm_path <- file.path(proc_dir, "thematicmap_scopus.rds")
if (file.exists(tm_path)) {
  TM <- readRDS(tm_path)
  w  <- as_tibble(TM$words)
  occ_col <- intersect(c("Occurrences", "freq", "Freq"), names(w))[1]
  clu_col <- intersect(c("Cluster_Label", "Cluster"), names(w))[1]
  if (!is.na(occ_col) && !is.na(clu_col)) {
    theme_tbl <- w %>%
      group_by(.cluster = .data[[clu_col]]) %>%
      summarise(label = .data[["Words"]][which.max(.data[[occ_col]])],
                weight = sum(.data[[occ_col]]), .groups = "drop") %>%
      arrange(desc(weight))
    theme_labels <- paste(head(theme_tbl$label, 5), collapse = "; ")
  }
}

# ---- 5. ABSTRACT NUMBERS --------------------------------------------
perf <- performance_summary(M_scopus)
top3 <- conc_s$shares %>% head(3) %>%
  mutate(entry = sprintf("%s (%.1f%%)", country, 100 * share)) %>% pull(entry)

abstract_numbers <- tibble(
  quantity = c(
    "Total records (Scopus, primary)",
    "Total records (OpenAlex, validation)",
    "Year span",
    "CAGR (%/yr, Scopus)",
    "Top-1 country", "Top-2 country", "Top-3 country",
    "Top-5 concentration share (%, Scopus)",
    "HHI (Scopus)", "HHI (OpenAlex)",
    "South Asia share (%, Scopus)",
    "South Asia share (%, OpenAlex)",
    "Spearman rho (cross-DB country shares)",
    "Country-field used (Scopus)",
    "Country-field used (OpenAlex)",
    "Dominant thematic clusters",
    "OpenAlex pull date"),
  value = c(
    conc_s$n_total,
    conc_oa$n_total,
    sprintf("%d-%d", perf$year_range[1], perf$year_range[2]),
    sprintf("%.1f", 100 * perf$cagr),
    top3[1], top3[2], top3[3],
    sprintf("%.1f", 100 * conc_s$top5_share),
    sprintf("%.4f", conc_s$hhi),
    sprintf("%.4f", conc_oa$hhi),
    sprintf("%.2f", 100 * conc_s$south_asia_share),
    sprintf("%.2f", 100 * conc_oa$south_asia_share),
    sprintf("%.3f", rho),
    conc_s$country_field,
    conc_oa$country_field,
    ifelse(is.na(theme_labels), "see thematic_clusters_scopus.csv", theme_labels),
    tryCatch(readLines(file.path(proc_dir, "openalex_pull_date.txt"))[1],
             error = function(e) as.character(Sys.Date())))
)
write_csv(abstract_numbers, file.path(table_dir, "abstract_numbers.csv"))
cat("\n================ ABSTRACT NUMBERS ================\n")
print(abstract_numbers, n = Inf)
cat("\nSaved -> outputs/tables/abstract_numbers.csv\n")
