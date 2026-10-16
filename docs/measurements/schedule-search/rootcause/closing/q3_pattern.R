# q3_pattern.R: what differs between the dry-type records and the wet ones at closing edges.
# Per case (pilot record, b1 to 25): closing edges, spells and gaps; the share of establishment
# born within 36 d / 12 d before a closing edge; the committed last-interval width; and from
# the res runs (where present) fate curvature and the region error.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
for (cs in c("dry", "dry-p50", "dry-flat", "long-wet", "wet-adG2", "episodic", "long-drought")) {
  cr <- PIL[[cs]]$cr; b1 <- PIL[[cs]]$b1; et <- edge_table(cs); ce <- et[!et$opening & et$b > b1, ]
  g <- seq(b1, 25, by = 0.25 / 365); r <- cr$rate[pmax(1, findInterval(g, cr$start))]; tot <- sum(r)
  near <- function(dd) sum(r[vapply(g, function(t) any(t <= ce$b & t > ce$b - dd / 365), TRUE)]) / tot
  S <- rd(sprintf("val_insk_c_%s", cs))$node_times; A <- closing_anatomy(S, cs); A <- A[A$edge > b1, ]
  long <- A$spell > 60
  f <- file.path(CL, sprintf("q2_fate_cl_res_%s.rds", cs)); k <- if (file.exists(f)) { R <- readRDS(f); L <- R[R$spell > 60, ]; median((L$s_mid - L$s_far) / 17 * 10, na.rm = TRUE) } else NA
  rr <- file.path(CL, "runs", sprintf("cl_res_%s.rds", cs)); reg <- if (file.exists(rr) && !is.null(readRDS(rr)$stand$elasticity)) -mv_run(readRDS(rr), rd(sprintf("val_insk_c_%s", cs))) else NULL
  cat(sprintf("%-12s closing %3d (long %2d) | spell med %4.0f gap med %3.0f (long-spell gaps %3.0f) | estab share last 36 d %.2f, last 12 d %.3f | h_end med (long) %3.0f | k_far %.2f | region rms %s M %s hyd %s\n",
    cs, nrow(A), sum(long), median(A$spell), median(A$gap), median(A$gap[long]), near(36), near(12), median(A$h_end[long]), k,
    if (is.null(reg)) "-" else sprintf("%.3f", r2(reg)), if (is.null(reg)) "-" else sprintf("%+.2f", onM(reg)), if (is.null(reg)) "-" else sprintf("%.3f", r2(reg[intersect(HYD, names(reg))])))) }
