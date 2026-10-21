suppressMessages(library(plant))
tm <- function(expr, n = 3) { e <- substitute(expr); f <- parent.frame(); median(replicate(n, system.time(eval(e, f))[["elapsed"]])) }
L <- as.numeric(Sys.getenv("LT", "60"))
for (ns in as.integer(strsplit(Sys.getenv("NS", "1,2,4"), ",")[[1]])) {
  p <- scm_base_parameters("FF16"); p$max_patch_lifetime <- L
  lma <- c(0.0825, 0.12, 0.2, 0.06)[seq_len(ns)]
  p <- add_strategies(p, trait_matrix(lma, "lma"), birth_rate = as.list(rep(1, ns)))
  ctrl <- Control(node_density_in_birth_date = TRUE)
  run <- tm(run_scm(p, NULL, ctrl))
  scm <- run_scm(p, NULL, ctrl, record_trajectory = TRUE)
  g <- stand_gradient(scm)
  one <- tm(stand_gradient(scm, metrics = rownames(g$gradient)[1]))
  all <- tm(stand_gradient(scm))
  cat(sprintf("%-3s L=%g species=%d nodes=%d metrics=%d columns=%d | forward %.3fs | 1 metric %.3fs (%.1fx) | all %d metrics %.3fs (%.1fx) | per metric %.3fs\n",
      Sys.getenv("ARM"), L, ns, sum(sapply(seq_len(ns), function(i) scm$patch$species[[i]]$size)),
      nrow(g$gradient), ncol(g$gradient), run, one, one / run, nrow(g$gradient), all, all / run,
      (all - one) / (nrow(g$gradient) - 1)))
}
