# Geographic Concentration of AI-in-Radiology Research, 2015–2025

A bibliometric (meta-research) analysis of the global artificial-intelligence-in-radiology
literature. **Central thesis (geographic):** this research is heavily concentrated in a few
high-income countries, with a measurable South Asia / LMIC production gap. Headline outputs
are concentration statistics and a South Asia research-output share, **cross-validated across
two databases** (Scopus + OpenAlex).

---

## Data sources

| Role | Source | Records | Notes |
|------|--------|---------|-------|
| **Primary** | Scopus | 40,828 (after de-dup) | 11 year-wise CSV exports 2015–2025, exported **without** references (co-citation out of scope). |
| **Validation** | OpenAlex | ~19.4k (partial) – see note | Pulled live via `openalexR`; cached to `data/raw/openalex_raw.rds`. Polite-pool email: `mailforgauravmishra@gmail.com`. |

**OpenAlex pull date:** see `data/processed/openalex_pull_date.txt` (this run: 2026-06-29).

> ⚠️ **Scopus export parity is mandatory.** Every year CSV must be exported with the *same*
> field selection (Citation **+** Bibliographical **+** Abstract & keywords). If affiliations
> are missing from any file, `convert2df()` dies with `strsplit(DATA$C1, ";") : non-character
> argument`. (2015/2016 were initially mis-exported with only 19 of 33 columns.)

> ⚠️ **OpenAlex completeness.** OpenAlex reports ~59.8k matching works; a single 2015–2025
> pull is silently truncated when the API returns HTTP 429 mid-stream (openalexR keeps the
> partial set, **returning 0 rows on a 429 without raising an error**). `02_pull_openalex.R`
> therefore pulls **one calendar quarter at a time**, caches each chunk to
> `data/raw/oa_chunks/`, and treats an empty result as a retryable failure (every quarter of
> this corpus is non-empty) so throttled zeros are never cached. The final
> `data/raw/openalex_raw.rds` is written only once all 44 quarters are present.
>
> **Current state:** the active corpus is a **partial 19,400-record** pull (spans 2015–2025;
> recent years under-counted). A complete re-pull reached **27/44 quarters (2015–2021 complete,
> 14.5k records)** before OpenAlex began sustained 429-throttling this IP; 2022–2025 are not yet
> captured. **To finish it:** delete `data/raw/openalex_raw.rds` and re-run `R/02_pull_openalex.R`
> when the API is not throttling — it resumes from the 27 cached chunks. The headline pattern
> (ρ ≈ 0.84, top-5 ≈ 60 %, South-Asia bias direction) is stable; only the exact OpenAlex shares
> will firm up.

---

## Search strategies (the methodology — reproduce verbatim)

### Scopus (run per-year; only the `PUBYEAR` bounds change)
```
TITLE ( "artificial intelligence" OR "machine learning" OR "deep learning"
        OR "convolutional neural network" OR "radiomics" )
AND TITLE-ABS-KEY ( "radiology" OR "radiological" OR "radiograph"
        OR "computed tomography" OR "magnetic resonance imaging" OR "mammography"
        OR "medical imaging" OR "diagnostic imaging" OR "interventional radiology" )
AND PUBYEAR > 2014 AND PUBYEAR < 2026
AND ( DOCTYPE ( ar ) OR DOCTYPE ( re ) ) AND LANGUAGE ( english )
```

### OpenAlex (mirrors the Scopus structure for parity)
AI terms in **title**, radiology terms in **title + abstract**. OpenAlex `.search` filters use
`|` for OR (the word "OR" is taken literally → use the pipe). Two separate `.search` filters
are AND-combined.
```r
oa_fetch(entity = "works",
         title.search              = "artificial intelligence|machine learning|deep learning|convolutional neural network|radiomics",
         title_and_abstract.search = "radiology|radiological|radiograph|computed tomography|magnetic resonance imaging|mammography|medical imaging|diagnostic imaging|interventional radiology",
         from_publication_date = "2015-01-01", to_publication_date = "2025-12-31",
         type = "article")
```
**Deliberately drops bare "neural network"** (it pulls brain-network neuroimaging papers, not AI).

---

## Pipeline

```
run_all.R                 # reproduces everything end to end
R/00_functions.R          # shared: concentration(), performance_summary(), oa_extract_countries()
R/01_import_scopus.R      # import + merge 11 CSVs -> M_scopus; AU1_CO/AU_CO country tags
R/02_pull_openalex.R      # per-year OpenAlex pull -> M_oa; ISO-2 countries from authorships
R/03_concentration.R      # performance + concentration on Scopus
R/04_science_mapping.R    # country collaboration / keyword co-occurrence / thematic map
R/05_validation.R         # cross-DB comparison, Spearman rho, abstract_numbers.csv
```

Run: `"C:/Program Files/R/R-4.5.2/bin/Rscript.exe" run_all.R`

### Key design choices
- **Country field.** `concentration()` uses corresponding-author country (`AU1_CO`) when its
  coverage ≥ 70 %, else falls back to first-author country (`AU_CO[1]`); the choice used is
  reported in every output. Scopus coverage = 95.2 %, OpenAlex = 87.1 % → both use AU1_CO.
- **Country harmonisation.** Scopus labels are country **names** (`origin = "country.name"`);
  OpenAlex labels are **ISO-2 codes** parsed from the authorship affiliations
  (`origin = "iso2c"`). Both map to ISO-3 via `countrycode`.
- **South Asia ISO-3 set:** NPL, IND, PAK, BGD, LKA, BTN, MDV, AFG.
- **Keyword network** is built directly with `igraph` on the top-N keywords; bibliometrix's
  `biblioNetwork()` segfaults materialising the full term×term matrix on 40k papers.

---

## Headline results (this run)

| Metric | Scopus | OpenAlex |
|---|---|---|
| N records | 40,828 | 19,400* |
| CAGR (2015→2025) | 63.6 %/yr | — |
| Top-3 countries | China 32.2 %, USA 15.2 %, India 6.1 % | China 21.5 %, USA 17.2 %, India 10.1 % |
| Top-5 concentration share | 63.0 % | 58.3 % |
| HHI (country shares) | 0.141 | 0.097 |
| South Asia share | **7.13 %** | **12.14 %** |
| Spearman ρ (per-country shares, both DBs) | **0.844** (136 countries) | |

\* OpenAlex figure is from a (possibly truncated) pull; see the completeness note above.

**Interpretation.** High ρ (0.844) + same-order HHI ⇒ the geographic concentration pattern is
robust across databases. OpenAlex's *higher* South Asia share (12.1 % vs 7.1 %) quantifies
Scopus's coverage bias against the region. South-Asian output is itself hyper-concentrated in
India; the rest of the region (PAK/BGD/LKA/NPL/…) is ≈ 1 % combined.

---

## Methods paragraph (adapt for the abstract)

> We performed a bibliometric meta-analysis of AI-in-radiology research published 2015–2025.
> The primary corpus was retrieved from Scopus (title-restricted AI terms intersected with
> title/abstract/keyword radiology terms; original articles and reviews; English; n = 40,828)
> and cross-validated against an OpenAlex corpus built with an equivalent query. Country of
> origin was assigned by corresponding-author affiliation (coverage 95.2 % / 87.1 %) and
> harmonised to ISO-3. Output concentration was summarised by the top-5 country share and the
> Herfindahl–Hirschman Index (HHI); regional output was measured as the combined South Asia
> share (NPL, IND, PAK, BGD, LKA, BTN, MDV, AFG). Cross-database robustness was assessed by the
> Spearman correlation of per-country shares. Research output was highly concentrated (top-5
> share 63.0 %, HHI 0.141), led by China (32.2 %) and the USA (15.2 %); South Asia contributed
> 7.1 % (Scopus) / 12.1 % (OpenAlex), almost entirely from India. The concentration pattern was
> consistent across databases (Spearman ρ = 0.844).

---

## Environment

R 4.5.2. Dependencies pinned with **renv** (`renv.lock`); restore with `renv::restore()`.

| Package | Version |
|---|---|
| bibliometrix | 5.4.1 |
| openalexR | 3.0.1 |
| tidyverse | 2.0.0 |
| countrycode | 1.8.0 |
| igraph | 2.3.2 |
| renv | 1.2.3 |

> R is installed at `C:\Program Files\R\R-4.5.2\bin\Rscript.exe` and is **not** on PATH on this
> machine — invoke with the full path.
