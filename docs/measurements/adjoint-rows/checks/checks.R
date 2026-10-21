source(file.path(Sys.getenv("CHECKS"), "fixture.R"))
out <- list()
say <- function(...) cat(sprintf(...), "\n")

# Per node: rows, the node's own index, and its entries' names.
intro_rows <- function(r) {
  w <- lengths(r$adjoint)
  which(r$introduction & c(FALSE, diff(w) > 0))
}
node_of_row <- function(r, k) {
  nm <- names(r$adjoint[[k]])
  max(as.integer(sub("^1\\.([0-9]+)\\..*", "\\1", nm[grepl("^1\\.[0-9]+\\.", nm)])))
}

check_one <- function(scm, metric, label) {
  cat("\n==== ", label, metric, "\n")
  value0 <- stand_fitness(scm)[[metric]]
  # (a) bit-identity: the default path before and after, and against on.
  t_off <- system.time(g_off <- stand_gradient(scm, metrics = metric))[["elapsed"]]
  h0 <- vmhwm()
  t_on <- system.time(r <- stand_adjoint_rows(scm, metric))[["elapsed"]]
  h1 <- vmhwm()
  t_off2 <- system.time(g_off2 <- stand_gradient(scm, metrics = metric))[["elapsed"]]
  value1 <- stand_fitness(scm)[[metric]]
  g <- g_off$gradient[metric, ]
  same_on <- identical(unname(g), unname(r$gradient[names(g)])) &&
    identical(names(g), names(r$gradient))
  say("(a) value %.15g; unchanged after on: %s; gradient off == on (identical): %s; off before == off after: %s",
      value0, identical(value0, value1), same_on,
      identical(g_off$gradient, g_off2$gradient))
  rec <- scm$store_trajectory()
  widths <- vapply(rec, function(x) length(x$state), 1L)
  say("    rows %d, introduction rows %d (node-adding %d), state doubles %d; widths match: %s",
      length(rec), sum(r$introduction), length(intro_rows(r)), sum(widths),
      identical(unname(lengths(r$adjoint)), widths))
  say("    times identical to store_trajectory: %s",
      identical(r$time, vapply(rec, `[[`, 1, "time")))

  # (b) the mortality identity at each node's introduction row.
  last <- length(rec)
  lamT <- r$adjoint[[last]]; yT <- rec[[last]]$state; names(yT) <- names(lamT)
  ir <- intro_rows(r)
  tab <- do.call(rbind, lapply(ir, function(k) {
    j <- node_of_row(r, k)
    off <- sprintf("1.%d.offspring_produced_survival_weighted", j)
    d <- lamT[[off]] * yT[[off]]
    lm_wide <- r$adjoint[[k]][[sprintf("1.%d.mortality", j)]]
    data.frame(row = k, node = j, time = r$time[k], d = d, lambda_mortality = lm_wide,
               residual = lm_wide + d)
  }))
  print(signif(tab, 6))
  say("(b) max |lambda_mortality + d_k| = %.3g against max d_k %.3g; sum d_k = %.12g vs metric %.12g",
      max(abs(tab$residual)), max(abs(tab$d)), sum(tab$d), value0)

  # (c) injection: replay from a recorded row with one state entry moved.
  base <- plant:::census_row_replay_tf24(scm, 0L, rec[[1]]$state)
  names(base) <- plant:::stand_metric_table(scm)$name
  say("(c) unperturbed replay from row 0: %.15g (run %.15g, rel %.2g)",
      base[[metric]], value0, base[[metric]] / value0 - 1)
  steps <- which(!r$introduction & seq_along(rec) > 1 & seq_along(rec) < last)
  mid <- steps[which.min(abs(r$time[steps] - LIFETIME / 2))]
  pre <- ir[length(ir) %/% 2] - 1L   # the step row just below an introduction
  inj <- list()
  for (k in unique(c(mid, pre))) {
    y <- rec[[k]]$state; nm <- names(r$adjoint[[k]])
    jn <- node_of_row(r, k)
    picks <- c(sprintf("1.%d.%s", c(1, jn, jn), c("height", "mortality", "storage")),
               sprintf("1.%d.mortality", max(1, jn %/% 2)), "env.1", "env.3")
    picks <- intersect(picks, nm)
    for (p in picks) {
      i <- match(p, nm)
      h <- 1e-5 * max(abs(y[i]), 1e-2)
      up <- y; up[i] <- up[i] + h; dn <- y; dn[i] <- dn[i] - h
      fu <- plant:::census_row_replay_tf24(scm, k - 1L, up)
      fd <- plant:::census_row_replay_tf24(scm, k - 1L, dn)
      m <- match(metric, plant:::stand_metric_table(scm)$name)
      cd <- (fu[m] - fd[m]) / (2 * h)
      inj[[length(inj) + 1]] <- data.frame(row = k, time = r$time[k], entry = p,
                                           adjoint = r$adjoint[[k]][[i]], central = cd,
                                           rel = (r$adjoint[[k]][[i]] - cd) / max(abs(cd), 1e-300))
    }
  }
  # The wide side: replay from the state the middle introduction reached.
  kw <- ir[length(ir) %/% 2]
  range <- sum(r$introduction[seq_len(kw)])
  y <- rec[[kw]]$state; nm <- names(r$adjoint[[kw]]); jn <- node_of_row(r, kw)
  for (p in intersect(sprintf("1.%d.%s", jn, c("mortality", "height", "storage")), nm)) {
    i <- match(p, nm)
    h <- 1e-5 * max(abs(y[i]), 1e-2)
    up <- y; up[i] <- up[i] + h; dn <- y; dn[i] <- dn[i] - h
    m <- match(metric, plant:::stand_metric_table(scm)$name)
    cd <- (plant:::ladder_census_initial_state_replay_tf24(scm, up, range)[m] -
           plant:::ladder_census_initial_state_replay_tf24(scm, dn, range)[m]) / (2 * h)
    inj[[length(inj) + 1]] <- data.frame(row = kw, time = r$time[kw], entry = paste(p, "(wide)"),
                                         adjoint = r$adjoint[[kw]][[i]], central = cd,
                                         rel = (r$adjoint[[kw]][[i]] - cd) / max(abs(cd), 1e-300))
  }
  inj <- do.call(rbind, inj)
  print(inj, digits = 8)

  # (4) cost.
  kept_bytes <- sum(lengths(r$adjoint)) * 8
  say("(cost) sweep off %.2f s, %.2f s; on %.2f s (on/off %.3f); VmHWM %.0f -> %.0f MB; kept doubles %d (%.2f MB), R object %.2f MB",
      t_off, t_off2, t_on, t_on / mean(c(t_off, t_off2)), h0, h1,
      sum(lengths(r$adjoint)), kept_bytes / 2^20,
      as.numeric(object.size(r)) / 2^20)
  list(off = g_off, on = r, mortality = tab, injection = inj,
       time = c(off = t_off, off2 = t_off2, on = t_on), hwm = c(h0, h1))
}

t_run <- system.time(res <- fixture_run())[["elapsed"]]
say("resident run %.1f s, J = %.12g", t_run, res$offspring_production)
out$resident <- check_one(res, "1.offspring_production", "resident")
res$record_trajectory <- TRUE
t_inv <- system.time(res$run_mutant(fixture_parameters(1)))[["elapsed"]]
say("invader run %.1f s, R' = %.12g", t_inv, res$net_reproduction_ratios)
out$invader <- check_one(res, "1.net_reproduction_ratio", "invader")

bl <- file.path(Sys.getenv("CHECKS"), paste0("baseline-", NODES, ".rds"))
if (file.exists(bl)) {
  b <- readRDS(bl)
  say("\n(a) against the unmodified build: resident gradient identical %s, invader %s",
      identical(b$gr$gradient, out$resident$off$gradient),
      identical(b$gi$gradient, out$invader$off$gradient))
}
saveRDS(out, file.path(Sys.getenv("CHECKS"), paste0("checks-", NODES, ".rds")))
