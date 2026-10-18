suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
E <- file.path(SP, "epi"); O <- file.path(SP, "refine/s05/epi-adG208")
rd <- function(f) { if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$finished)) NULL else qv(x) / EPS }
b1 <- rd(file.path(O, "level1.rds")); b2 <- rd(file.path(O, "level2.rds"))
d <- function(n, b) { q <- rd(file.path(E, "runs", paste0(n, ".rds"))); if (is.null(q)) rep(NA, length(Q)) else q - b }
CD1 <- d("l1m_C", b1) + d("l1m_D", b1); CD2 <- d("l2m_C", b2) + d("l2m_D", b2)
t <- data.frame(end1 = d("l1z_end", b1), end2 = d("l2z_end", b2), open1 = d("l1z_open", b1), open2 = d("l2z_open", b2), short1 = d("l1z_short", b1), short2 = d("l2z_short", b2), CD1 = CD1, CD2 = CD2)
t$int1 <- t$CD1 - t$end1 - t$open1 - ifelse(is.na(t$short1), 0, t$short1); t$int2 <- t$CD2 - t$end2 - t$open2 - ifelse(is.na(t$short2), 0, t$short2)
t$r_end <- t$end1 / t$end2; t$r_open <- t$open1 / t$open2; t$r_short <- t$short1 / t$short2; t$r_int <- t$int1 / t$int2; t$r_CD <- t$CD1 / t$CD2
rownames(t) <- Q; qs <- c("a_l1", "lnJ", "a", "k_I", "jmax_25", "lma", "R_d_25", "storage_relaxation_offset", "a_st3", "a_dG1", "k_s", "hmat", "TF24_cost_scale")
options(width = 200); print(round(t[qs, ], 3))
