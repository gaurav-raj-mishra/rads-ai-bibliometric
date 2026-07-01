# =====================================================================
# 02_pull_openalex.R
# Validation corpus: pull AI-in-radiology works from OpenAlex (live API).
# Output: data/raw/openalex_raw.rds       (raw oa_fetch result, cached)
#         data/processed/M_oa.rds         (bibliometrix data frame)
#
# Search strategy (mirrors the Scopus structure for parity):
#   AI terms        -> title.search
#   radiology terms -> title_and_abstract.search
#   window 2015-01-01 .. 2025-12-31, type = "article"
# Deliberately DROPS bare "neural network" (pulls brain-network
# neuroimaging papers, not AI). The raw pull is cached to .rds so the
# API is never re-hit on subsequent runs.
# =====================================================================

suppressPackageStartupMessages({
  library(openalexR)
  library(bibliometrix)
  library(tidyverse)
})
source("R/00_functions.R")   # oa_extract_countries()

# Polite pool (no key needed) — faster + good practice.
options(openalexR.mailto = "mailforgauravmishra@gmail.com")

raw_dir  <- "data/raw"
proc_dir <- "data/processed"
dir.create(proc_dir, showWarnings = FALSE, recursive = TRUE)
raw_rds  <- file.path(raw_dir, "openalex_raw.rds")

# ---- 1. Search strings ----------------------------------------------
# IMPORTANT: OpenAlex .search filters use "|" for OR, NOT the word "OR".
# (Passing "x OR y" makes OpenAlex search for the literal token "or" and
#  AND-match the rest -> a handful of hits. "x|y" is the correct OR.)
# AND between the two concepts is achieved by using two separate filters.
ai_terms  <- "artificial intelligence|machine learning|deep learning|convolutional neural network|radiomics"
rad_terms <- "radiology|radiological|radiograph|computed tomography|magnetic resonance imaging|mammography|medical imaging|diagnostic imaging|interventional radiology"

# ---- 2. Fetch (cached; PER-QUARTER with on-disk chunk cache) --------
# A single 2015-2025 pull paginates ~300 pages and silently truncates if
# OpenAlex 429s mid-stream; whole-year pulls of the big recent years time
# out. So we pull one CALENDAR QUARTER at a time (small, completes well
# under the request timeout) and cache each chunk to disk, so a failure
# never loses progress and a re-run resumes where it stopped.
# NOTE: oa_fetch(count_only=TRUE) segfaults in openalexR 3.0.1 here.
chunk_dir <- file.path(raw_dir, "oa_chunks")
dir.create(chunk_dir, showWarnings = FALSE, recursive = TRUE)

# Every quarter of this 2015-2025 corpus is non-empty, so an empty/NULL
# return means a swallowed HTTP 429 (openalexR returns 0 rows, no error)
# -> treat empty as a retryable failure with long backoff so zeros are
# never cached. Only a non-empty result is accepted.
pull_range <- function(from, to, tag, max_tries = 10) {
  for (i in seq_len(max_tries)) {
    res <- tryCatch(
      oa_fetch(entity = "works",
               title.search              = ai_terms,
               title_and_abstract.search = rad_terms,
               from_publication_date     = from,
               to_publication_date       = to,
               type                      = "article",
               verbose                   = FALSE),
      error = function(e) e)
    if (!inherits(res, "error") && !is.null(res) && nrow(res) > 0) return(res)
    reason <- if (inherits(res, "error")) conditionMessage(res) else "empty (likely 429)"
    wait <- min(30 * i, 180)                 # ramp to ~3 min, outlast throttle windows
    message(sprintf("  %s attempt %d failed (%s). Retry in %ds ...", tag, i, reason, wait))
    Sys.sleep(wait)
  }
  stop("OpenAlex fetch failed for ", tag, " after ", max_tries, " tries")
}

q_bounds <- list(c("01-01", "03-31"), c("04-01", "06-30"),
                 c("07-01", "09-30"), c("10-01", "12-31"))

if (file.exists(raw_rds)) {
  message("Cached OpenAlex pull found -> loading ", raw_rds,
          " (delete it to force a fresh API pull)")
  works <- readRDS(raw_rds)
} else {
  message("Pulling OpenAlex per quarter 2015-2025 (resumable; may take minutes) ...")
  for (y in 2015:2025) for (q in seq_along(q_bounds)) {
    tag  <- sprintf("%d_Q%d", y, q)
    cf   <- file.path(chunk_dir, sprintf("oa_%s.rds", tag))
    if (file.exists(cf)) next                       # resume: skip done chunks
    b  <- q_bounds[[q]]
    wq <- pull_range(sprintf("%d-%s", y, b[1]), sprintf("%d-%s", y, b[2]), tag)
    saveRDS(wq, cf)
    message(sprintf("  %s: %d records", tag, if (is.null(wq)) 0L else nrow(wq)))
    Sys.sleep(1)                                    # be polite between chunks
  }
  # Combine all cached chunks.
  chunks <- list.files(chunk_dir, pattern = "^oa_\\d{4}_Q\\d\\.rds$", full.names = TRUE)
  works  <- bind_rows(lapply(chunks, readRDS))
  works  <- distinct(works, id, .keep_all = TRUE)   # de-dup across chunks

  attr(works, "oa_pull_date") <- as.character(Sys.Date())
  saveRDS(works, raw_rds)   # only written after ALL chunks present
  writeLines(as.character(Sys.Date()), file.path(proc_dir, "openalex_pull_date.txt"))
  message("Saved raw pull -> ", raw_rds, "  (", nrow(works), " records)")
}
cat("OpenAlex raw records:", nrow(works), "\n")

# ---- 3. Convert to bibliometrix -------------------------------------
M_oa <- oa2bibliometrix(works)

# bibliometrix's AU1_CO/AU_CO are unreliable for OpenAlex, so overwrite
# them with ISO-2 codes parsed straight from the authorship affiliations.
# (Rows are aligned: oa2bibliometrix preserves works' row order.)
stopifnot(nrow(M_oa) == nrow(works))
co <- oa_extract_countries(works)
M_oa$AU1_CO <- co$au1       # one country / paper (corresponding->first->any)
M_oa$AU_CO  <- co$au_all    # ;-separated set of all author countries
# NOTE: OpenAlex labels are ISO-2 codes -> concentration(origin = "iso2c").

# ---- 4. INSPECT / sanity-check --------------------------------------
au1 <- M_oa$AU1_CO[!is.na(M_oa$AU1_CO) & M_oa$AU1_CO != ""]
cat("\nAU1_CO coverage (OpenAlex):",
    sprintf("%.1f%%", 100 * length(au1) / nrow(M_oa)), "\n")
cat("Top author countries (ISO-2):\n")
print(head(sort(table(au1), decreasing = TRUE), 12))

# ---- 5. Save --------------------------------------------------------
saveRDS(M_oa, file.path(proc_dir, "M_oa.rds"))
cat("\nSaved -> data/processed/M_oa.rds  (", nrow(M_oa), "records )\n")
