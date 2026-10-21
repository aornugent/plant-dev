# The injection residuals that exceed 1e-4: are they the difference's step?
source(file.path(Sys.getenv("CHECKS"), "fixture.R"))
res <- fixture_run()
metric <- "1.offspring_production"
r <- stand_adjoint_rows(res, metric)
rec <- res$store_trajectory()
m <- match(metric, plant:::stand_metric_table(res)$name)
replay <- function(k, y, wide) {
  if (wide) plant:::ladder_census_initial_state_replay_tf24(res, y, sum(r$introduction[seq_len(k)]))[m]
  else plant:::census_row_replay_tf24(res, k - 1L, y)[m]
}
probe <- function(k, entry, wide = FALSE) {
  y <- rec[[k]]$state; i <- match(entry, names(r$adjoint[[k]]))
  f0 <- replay(k, y, wide)
  for (rel in 10^-(3:8)) {
    h <- rel * max(abs(y[i]), 1e-2)
    up <- y; up[i] <- y[i] + h; dn <- y; dn[i] <- y[i] - h
    fu <- tryCatch(replay(k, up, wide), error = function(e) NA)
    fd <- tryCatch(replay(k, dn, wide), error = function(e) NA)
    cat(sprintf("%5d %-22s y %.4g  h %.1e  central %.8g  fwd %.8g  bwd %.8g  adjoint %.8g\n",
                k, entry, y[i], h, (fu - fd) / (2 * h), (fu - f0) / h, (f0 - fd) / h,
                r$adjoint[[k]][[i]]))
  }
}
probe(1451, "1.8.storage")
probe(1316, "1.7.mortality")
probe(1451, "env.3")
probe(1317, "1.8.mortality", TRUE)
probe(1317, "1.8.storage", TRUE)
