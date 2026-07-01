# =====================================================================
# 04_science_mapping.R   (primary = Scopus corpus)
#   (a) country collaboration network
#   (b) keyword co-occurrence network
#   (c) thematic map (centrality vs density quadrants)
# Author-keyword coverage is checked; if thin, falls back to index
# keywords (ID), then to title terms (TI).
# Figures -> outputs/figures/*.png  (300 dpi, publication quality)
# =====================================================================

suppressPackageStartupMessages({
  library(bibliometrix)
  library(tidyverse)
  library(igraph)
})

proc_dir <- "data/processed"
fig_dir  <- "outputs/figures"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

M <- readRDS(file.path(proc_dir, "M_scopus.rds"))

save_png <- function(file, expr, w = 2600, h = 2000, res = 300) {
  png(file.path(fig_dir, file), width = w, height = h, res = res)
  on.exit(dev.off())
  force(expr)
}

# ---- choose keyword field by coverage -------------------------------
cov <- function(x) mean(!is.na(x) & x != "")
de_cov <- cov(M$DE); id_cov <- if ("ID" %in% names(M)) cov(M$ID) else 0
kw_field <- if (de_cov >= 0.50) "DE" else if (id_cov >= 0.50) "ID" else "TI"
kw_net   <- switch(kw_field, DE = "author_keywords", ID = "keywords", TI = "titles")
cat(sprintf("Keyword field: %s (DE cov %.0f%%, ID cov %.0f%%)\n",
            kw_field, 100 * de_cov, 100 * id_cov))

# ---- (a) country collaboration network ------------------------------
cat("Building country collaboration network ...\n")
ok_a <- tryCatch({
  net_co <- biblioNetwork(M, analysis = "collaboration", network = "countries", sep = ";")
  save_png("country_collaboration_scopus.png", {
    networkPlot(net_co, n = 30, type = "fruchterman", Title = "",
                labelsize = 0.8, halo = FALSE, cluster = "walktrap",
                size = 6, size.cex = TRUE, edgesize = 3, alpha = 0.7)
  })
  TRUE
}, error = function(e) { message("country net failed: ", conditionMessage(e)); FALSE })

# ---- (b) keyword co-occurrence network ------------------------------
# Built directly with igraph on the TOP-N keywords. bibliometrix's
# biblioNetwork() materialises the full term x term matrix (tens of
# thousands of keywords from 40k papers) and segfaults; restricting to
# the top-N vocabulary first is both stable and more legible.
keyword_cooc_plot <- function(M, field, file, top_n = 40, min_edge = 3) {
  docs <- str_split(M[[field]], ";")
  docs <- lapply(docs, function(x) unique(str_squish(x[!is.na(x) & x != ""])))
  freq <- sort(table(unlist(docs)), decreasing = TRUE)
  top  <- names(freq)[seq_len(min(top_n, length(freq)))]
  docs <- lapply(docs, function(x) x[x %in% top])
  docs <- docs[lengths(docs) >= 2]
  edges <- do.call(rbind, lapply(docs, function(x) t(combn(sort(x), 2))))
  ew <- as_tibble(edges, .name_repair = ~c("from", "to")) %>%
    count(from, to, name = "weight") %>% filter(weight >= min_edge)
  g <- graph_from_data_frame(ew, directed = FALSE)
  V(g)$freq <- as.integer(freq[V(g)$name])
  V(g)$size <- scales::rescale(V(g)$freq, to = c(5, 20))
  cl <- cluster_louvain(g, weights = E(g)$weight)
  pal <- scales::hue_pal()(max(membership(cl)))
  V(g)$color <- pal[membership(cl)]
  set.seed(42); lay <- layout_with_fr(g, weights = E(g)$weight)
  save_png(file, {
    par(mar = c(0, 0, 0, 0))
    plot(g, layout = lay,
         vertex.label = V(g)$name, vertex.label.cex = 0.7,
         vertex.label.color = "black", vertex.label.family = "sans",
         vertex.frame.color = "white",
         edge.width = scales::rescale(E(g)$weight, to = c(0.4, 4)),
         edge.color = adjustcolor("grey60", 0.5))
  })
}
cat("Building keyword co-occurrence network ...\n")
ok_b <- tryCatch({
  keyword_cooc_plot(M, field = kw_field, file = "keyword_cooccurrence_scopus.png")
  TRUE
}, error = function(e) { message("keyword net failed: ", conditionMessage(e)); FALSE })

# ---- (c) thematic map -----------------------------------------------
cat("Building thematic map ...\n")
ok_c <- tryCatch({
  TM <- thematicMap(M, field = kw_field, n = 250, minfreq = 5,
                    size = 0.5, n.labels = 3, repel = TRUE)
  ggsave(file.path(fig_dir, "thematic_map_scopus.png"),
         TM$map, width = 9, height = 7, dpi = 300, bg = "white")
  # Persist the cluster table for the abstract's "dominant themes".
  write_csv(TM$words %>% as_tibble(),
            "outputs/tables/thematic_clusters_scopus.csv")
  saveRDS(TM, file.path(proc_dir, "thematicmap_scopus.rds"))
  TRUE
}, error = function(e) { message("thematic map failed: ", conditionMessage(e)); FALSE })

cat(sprintf("\nFigures written (a=%s, b=%s, c=%s) -> outputs/figures/\n", ok_a, ok_b, ok_c))
