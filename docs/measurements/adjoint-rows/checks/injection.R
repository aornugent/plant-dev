# (c) Injection with a step scaled to each entry (1e-5 relative, 1e-9 absolute
# below 1e-4), at a mid-run step row, the step row below an introduction (the
# narrow side) and that introduction's own row (the wide side).
source(file.path(Sys.getenv("CHECKS"), "fixture.R"))
inject <- function(scm, metric, label) {
  r <- stand_adjoint_rows(scm, metric)
  rec <- scm$store_trajectory()
  m <- match(metric, plant:::stand_metric_table(scm)$name)
  w <- lengths(r$adjoint)
  ir <- which(r$introduction & c(FALSE, diff(w) > 0))
  kw <- ir[4]                          # node 4's introduction, t = 1.5
  steps <- which(!r$introduction & seq_along(rec) > 1 & seq_along(rec) < length(rec))
  mid <- steps[which.min(abs(r$time[steps] - 2.25))]
  out <- list()
  for (case in list(list(k = mid, wide = FALSE), list(k = kw - 1L, wide = FALSE),
                    list(k = kw, wide = TRUE))) {
    k <- case$k; y <- rec[[k]]$state; nm <- names(r$adjoint[[k]])
    jn <- max(as.integer(sub("^1\\.([0-9]+)\\..*", "\\1", nm[grepl("^1\\.[0-9]+\\.", nm)])))
    picks <- intersect(c(sprintf("1.%d.%s", 1, c("height", "mortality", "storage")),
                         sprintf("1.%d.%s", jn, c("height", "mortality", "storage",
                                                  "offspring_produced_survival_weighted")),
                         "env.1", "env.3"), nm)
    run <- function(v) {
      if (case$wide) plant:::ladder_census_initial_state_replay_tf24(scm, v, sum(r$introduction[seq_len(k)]))[m]
      else plant:::census_row_replay_tf24(scm, k - 1L, v)[m]
    }
    for (p in picks) {
      i <- match(p, nm)
      h <- if (abs(y[i]) > 1e-4) 1e-5 * abs(y[i]) else 1e-9
      up <- y; up[i] <- y[i] + h; dn <- y; dn[i] <- y[i] - h
      cd <- (run(up) - run(dn)) / (2 * h)
      a <- r$adjoint[[k]][[i]]
      out[[length(out) + 1]] <- data.frame(who = label, row = k, t = r$time[k],
        side = if (case$wide) "wide" else if (k == kw - 1L) "narrow" else "step",
        entry = p, h = h, adjoint = a, central = cd,
        rel = if (cd == 0 && a == 0) 0 else (a - cd) / max(abs(cd), abs(a)))
    }
  }
  do.call(rbind, out)
}
res <- fixture_run()
a <- inject(res, "1.offspring_production", "resident")
res$record_trajectory <- TRUE
res$run_mutant(fixture_parameters(1))
b <- inject(res, "1.net_reproduction_ratio", "invader")
tab <- rbind(a, b)
options(width = 200)
print(tab, digits = 8, row.names = FALSE)
saveRDS(tab, file.path(Sys.getenv("CHECKS"), "injection.rds"))
