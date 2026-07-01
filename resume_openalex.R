# =====================================================================
# resume_openalex.R  —  unattended overnight completion of the OpenAlex
# pull, run by a one-off Windows scheduled task once the API throttle has
# reset. Resumes from the cached quarters in data/raw/oa_chunks/, and:
#   - on success  -> rebuilds M_oa from the COMPLETE corpus + refreshes
#                    cross-DB validation (R/05) and abstract_numbers.csv
#   - on failure  -> restores the known-good 19,400 corpus so the pipeline
#                    stays intact, and leaves the chunk cache for next time
# Writes a timestamped status to resume_log.txt at the project root.
# =====================================================================

setwd("C:/Research/Secondary analysis studies/rads_AI_bibliometric")
logf <- "resume_log.txt"
say  <- function(...) cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "-", ..., "\n",
                          file = logf, append = TRUE)

raw <- "data/raw/openalex_raw.rds"
bak <- "data/raw/openalex_raw_19400.rds.bak"

say("=== resume started ===")
n_chunks_before <- length(list.files("data/raw/oa_chunks", pattern = "\\.rds$"))
say("cached quarters before:", n_chunks_before, "/ 44")

# Force R/02 to resume the per-quarter pull (skips the chunks already cached).
if (file.exists(raw)) file.remove(raw)

ok <- tryCatch({ source("R/02_pull_openalex.R"); TRUE },
               error = function(e) { say("R/02 failed:", conditionMessage(e)); FALSE })

n_chunks_after <- length(list.files("data/raw/oa_chunks", pattern = "\\.rds$"))
say("cached quarters after:", n_chunks_after, "/ 44")

if (ok && file.exists(raw) && n_chunks_after == 44) {
  works_n <- nrow(readRDS(raw))
  say("COMPLETE pull succeeded:", works_n, "records. Refreshing validation ...")
  tryCatch({ source("R/05_validation.R"); say("R/05 done -> abstract_numbers.csv refreshed.") },
           error = function(e) say("R/05 failed:", conditionMessage(e)))
  say("=== DONE (complete corpus) ===")
} else {
  # Still throttled / incomplete: restore the working 19,400 corpus AND
  # rebuild M_oa + abstract_numbers from it so all deliverables stay in sync
  # (R/02 loads the restored cache without hitting the API).
  if (file.exists(bak)) file.copy(bak, raw, overwrite = TRUE)
  tryCatch({ source("R/02_pull_openalex.R"); source("R/05_validation.R")
             say("Rebuilt M_oa + abstract_numbers from restored 19,400 corpus.") },
           error = function(e) say("restore-rebuild failed:", conditionMessage(e)))
  say("INCOMPLETE (", n_chunks_after, "/44 ). Restored 19,400 corpus. Re-run later to finish.")
  say("=== DONE (incomplete; pipeline intact) ===")
}
