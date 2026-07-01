# data/raw — inputs (not committed)

The raw inputs are **not** included in this repository. Recreate them as follows.

## Scopus (primary) — `scopus_2015.csv` … `scopus_2025.csv`
Downloaded Scopus records may not be redistributed publicly under Elsevier's licence,
so they are git-ignored. To reproduce, run this query in Scopus **per year** (only the
`PUBYEAR` bounds change), export as **CSV with the SAME field selection every year**
(Citation + Bibliographical information incl. *Authors with affiliations* and
*Correspondence Address* + Abstract & keywords), and save as `scopus_<year>.csv`:

```
TITLE ( "artificial intelligence" OR "machine learning" OR "deep learning"
        OR "convolutional neural network" OR "radiomics" )
AND TITLE-ABS-KEY ( "radiology" OR "radiological" OR "radiograph"
        OR "computed tomography" OR "magnetic resonance imaging" OR "mammography"
        OR "medical imaging" OR "diagnostic imaging" OR "interventional radiology" )
AND PUBYEAR > 2014 AND PUBYEAR < 2026
AND ( DOCTYPE ( ar ) OR DOCTYPE ( re ) ) AND LANGUAGE ( english )
```

> All year files must share an identical field selection, or `convert2df()` fails with
> `strsplit(DATA$C1, ";") : non-character argument` (a missing affiliations column).

## OpenAlex (validation) — `openalex_raw.rds`
Pulled live (CC0 data, no key needed) by `R/02_pull_openalex.R`, which caches per-quarter
chunks to `oa_chunks/` and writes `openalex_raw.rds`. Both are git-ignored (large/regenerable).
Just run the script; set the polite-pool email at the top first.
