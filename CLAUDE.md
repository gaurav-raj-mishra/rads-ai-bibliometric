# CLAUDE.md — project conventions & context

Bibliometric meta-research on **AI-in-radiology, 2015–2025**. Thesis is **geographic**:
output concentrated in a few high-income countries with a South Asia / LMIC gap, cross-validated
Scopus (primary) vs OpenAlex (validation). Deliverable: RRF 2026 conference abstract,
**deadline 1 July 2026** — optimise for a correct working result, then polish.

## Running R on this machine
- R 4.5.2 is **not on PATH**. Use the full path:
  `"/c/Program Files/R/R-4.5.2/bin/Rscript.exe"` (Bash) / `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe"` (PowerShell).
- **`Rscript -e '...'` inline commands segfault on this setup** (Windows + Git Bash quoting).
  Always put throwaway/debug code in a `.R` **file** and run the file. Script files run fine.
- Heavy `cat()` output piped through `grep`/`head` sometimes shows nothing — write results to a
  file with `writeLines()`/`sink()` and read the file.

## Pipeline (numbered, idempotent)
`run_all.R` sources `R/01..05` in order. `R/00_functions.R` holds shared helpers
(`concentration()`, `performance_summary()`, `oa_extract_countries()`) and is sourced by 02/03/05.
Intermediate corpora: `data/processed/M_scopus.rds`, `M_oa.rds`. Outputs: `outputs/figures/`,
`outputs/tables/` (headline figures in `abstract_numbers.csv`).

## Search methodology (do not change without recording why)
- **Scopus:** `TITLE(ai terms) AND TITLE-ABS-KEY(radiology terms) AND PUBYEAR>2014 AND
  PUBYEAR<2026 AND (DOCTYPE(ar) OR DOCTYPE(re)) AND LANGUAGE(english)`, run per-year.
- **OpenAlex:** mirror — AI terms in `title.search`, radiology terms in
  `title_and_abstract.search`, `type="article"`, 2015-01-01..2025-12-31.
  Use **`|` for OR** (not the word "OR"). Two `.search` filters = AND.
- Both **drop bare "neural network"** (brain-network neuroimaging false positives).
- AI terms: artificial intelligence, machine learning, deep learning, convolutional neural
  network, radiomics. Radiology terms: radiology, radiological, radiograph, computed tomography,
  magnetic resonance imaging, mammography, medical imaging, diagnostic imaging,
  interventional radiology.

## Gotchas already hit (don't rediscover)
1. **Scopus field parity** — every year CSV must share the *same* export fields. Missing
   affiliation column ⇒ `convert2df` error `strsplit(DATA$C1, ";") : non-character argument`.
   Sanity-check column counts across files before importing.
2. **OpenAlex country data** — `oa2bibliometrix()` does NOT populate `AU1_CO` correctly (it
   collapsed to a single garbage country). Parse ISO-2 codes from `works$authorships`
   `affiliations` instead (`oa_extract_countries()`), then `concentration(origin="iso2c")`.
3. **OpenAlex truncation** — a single big pull truncates on a mid-stream 429. Pull per-year.
4. **bibliometrix `biblioNetwork()` keyword co-occurrence segfaults** on the full 40k-paper
   term matrix. Build the keyword network directly with `igraph` on the top-N terms.
5. **`oa_fetch(count_only=TRUE)` segfaults** in openalexR 3.0.1 here — use `group_by` or the
   verbose pull total instead.

## Conventions
- Country one-per-paper = corresponding author (`AU1_CO`); fall back to first author if coverage
  < 70 %. Always report which field was used.
- South Asia ISO-3 set: NPL, IND, PAK, BGD, LKA, BTN, MDV, AFG.
- Concentration metrics: top-5 share, HHI (= Σ share²), combined South Asia share.
- Figures: 300 dpi PNG to `outputs/figures/`.
- Dependencies pinned with renv (`renv.lock`).
