# =====================================================================
# 00_functions.R
# Shared helpers sourced by 03_concentration.R and 05_validation.R.
#   - concentration(): the ONE reusable headline-metrics function
#   - performance_summary(): annual production, CAGR, top-N tables
# =====================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(countrycode)
})

# South Asia ISO3 set (the LMIC / research-gap focus).
SOUTH_ASIA_ISO3 <- c("NPL", "IND", "PAK", "BGD", "LKA", "BTN", "MDV", "AFG")

# ---------------------------------------------------------------------
# oa_extract_countries(works)
# bibliometrix's oa2bibliometrix() does NOT populate corresponding-author
# country from OpenAlex (AU1_CO collapses to a single garbage value).
# OpenAlex carries the ISO-2 country code inside each authorship's
# `affiliations` vector, with is_corresponding / author_position flags.
# This pulls one country per paper (corresponding -> first -> any author)
# plus the ;-separated set of all author countries, as ISO-2 codes.
# Returns list(au1 = chr[n], au_all = chr[n]) aligned to works row order.
# ---------------------------------------------------------------------
oa_extract_countries <- function(works) {
  cc_of_aff <- function(aff) {
    if (is.null(aff) || length(aff) == 0) return(NA_character_)
    aff <- str_trim(as.character(aff))
    cc  <- aff[!is.na(aff) & str_detect(aff, "^[A-Z]{2}$")]
    if (length(cc)) cc[1] else NA_character_
  }
  pick <- function(auth) {
    if (is.null(auth) || !is.data.frame(auth) || nrow(auth) == 0)
      return(c(NA_character_, NA_character_))
    ccs  <- vapply(auth$affiliations, cc_of_aff, character(1))
    anyc <- which(!is.na(ccs))
    corr <- which((auth$is_corresponding %in% TRUE) & !is.na(ccs))
    fp   <- which((auth$author_position == "first") & !is.na(ccs))
    main <- if (length(corr)) ccs[corr[1]]
            else if (length(fp)) ccs[fp[1]]
            else if (length(anyc)) ccs[anyc[1]] else NA_character_
    c(main, if (length(anyc)) paste(unique(ccs[anyc]), collapse = ";") else NA_character_)
  }
  m <- t(vapply(works$authorships, pick, character(2)))
  list(au1 = m[, 1], au_all = m[, 2])
}

# ---------------------------------------------------------------------
# concentration(M, origin, label, coverage_floor = 0.70)
#
#   M      : a bibliometrix data frame with AU1_CO / AU_CO tags already
#            added via metaTagExtraction().
#   origin : countrycode source coding of the country labels --
#            "country.name" for Scopus (labels are NAMES, e.g. "CHINA"),
#            "iso2c" for OpenAlex IF its labels are 2-letter codes.
#            INSPECT unique labels first to choose.
#   label  : a short tag for the corpus ("Scopus" / "OpenAlex").
#
# Country field selection: uses corresponding-author country (AU1_CO)
# when its coverage >= coverage_floor; otherwise falls back to the
# first-listed author country from AU_CO. The choice is reported back
# in $country_field.
#
# Returns a list:
#   $label, $country_field, $coverage, $n_total, $n_with_country,
#   $shares (tibble: iso3, country, n, share),
#   $top5_share, $hhi, $south_asia_share, $unmatched (labels dropped)
# ---------------------------------------------------------------------
concentration <- function(M, origin, label = "", coverage_floor = 0.70) {

  has <- function(x) !is.na(x) & x != ""
  au1_cov <- if ("AU1_CO" %in% names(M)) mean(has(M$AU1_CO)) else 0

  if (au1_cov >= coverage_floor && "AU1_CO" %in% names(M)) {
    raw <- M$AU1_CO
    field_used <- sprintf("corresponding-author (AU1_CO, coverage %.1f%%)",
                          100 * au1_cov)
  } else {
    # Fall back to the FIRST author country in the ;-separated AU_CO.
    first_co <- str_trim(str_split_fixed(M$AU_CO, ";", 2)[, 1])
    raw <- first_co
    fb_cov <- mean(has(raw))
    field_used <- sprintf("first-author (AU_CO[1], coverage %.1f%%; AU1_CO only %.1f%%)",
                          100 * fb_cov, 100 * au1_cov)
  }

  raw <- raw[has(raw)]
  raw <- str_trim(raw)

  # Harmonise to ISO3. Unmatched labels are reported, not silently kept.
  iso3 <- suppressWarnings(countrycode(raw, origin = origin, destination = "iso3c"))
  unmatched <- sort(unique(raw[is.na(iso3)]))
  ok <- !is.na(iso3)
  iso3 <- iso3[ok]

  shares <- tibble(iso3 = iso3) %>%
    count(iso3, name = "n") %>%
    mutate(country = countrycode(iso3, "iso3c", "country.name"),
           share   = n / sum(n)) %>%
    arrange(desc(n)) %>%
    select(iso3, country, n, share)

  list(
    label            = label,
    country_field    = field_used,
    coverage         = au1_cov,
    n_total          = nrow(M),
    n_with_country   = sum(shares$n),
    shares           = shares,
    top5_share       = sum(head(shares$share, 5)),
    hhi              = sum(shares$share^2),
    south_asia_share = sum(shares$share[shares$iso3 %in% SOUTH_ASIA_ISO3]),
    unmatched        = unmatched
  )
}

# Pretty one-line printer for a concentration() result.
print_concentration <- function(c) {
  cat(sprintf("\n--- Concentration: %s ---\n", c$label))
  cat("Country field   :", c$country_field, "\n")
  cat(sprintf("Records         : %d (with country: %d)\n", c$n_total, c$n_with_country))
  cat(sprintf("Top-5 share     : %.1f%%\n", 100 * c$top5_share))
  cat(sprintf("HHI             : %.4f\n", c$hhi))
  cat(sprintf("South Asia share: %.2f%%\n", 100 * c$south_asia_share))
  cat("Top 10 countries:\n")
  print(c$shares %>% mutate(share = sprintf("%.1f%%", 100 * share)) %>% head(10))
  if (length(c$unmatched)) cat("Unmatched labels:", paste(head(c$unmatched, 15), collapse = ", "), "\n")
}

# ---------------------------------------------------------------------
# performance_summary(M): annual production, CAGR, top sources/inst.
# ---------------------------------------------------------------------
performance_summary <- function(M) {
  yr <- suppressWarnings(as.integer(M$PY))
  annual <- tibble(PY = yr) %>% filter(!is.na(PY)) %>% count(PY, name = "n") %>% arrange(PY)

  # CAGR from first to last year with data (uses production counts).
  y0 <- annual$PY[1]; yN <- annual$PY[nrow(annual)]
  n0 <- annual$n[1];  nN <- annual$n[nrow(annual)]
  cagr <- (nN / n0)^(1 / (yN - y0)) - 1

  top_sources <- tibble(SO = M$SO) %>% filter(!is.na(SO), SO != "") %>%
    count(SO, name = "n", sort = TRUE) %>% head(15)

  inst_field <- if ("AU_UN" %in% names(M)) "AU_UN" else NA
  top_inst <- if (!is.na(inst_field)) {
    tibble(AU_UN = M$AU_UN) %>% filter(!is.na(AU_UN), AU_UN != "") %>%
      separate_rows(AU_UN, sep = ";") %>% mutate(AU_UN = str_trim(AU_UN)) %>%
      filter(AU_UN != "", AU_UN != "NA") %>%
      count(AU_UN, name = "n", sort = TRUE) %>% head(15)
  } else NULL

  list(annual = annual, cagr = cagr, year_range = c(y0, yN),
       n_total = nrow(M), top_sources = top_sources, top_inst = top_inst)
}
