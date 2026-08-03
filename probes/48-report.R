# Final assembly: Pareto tables, convergence limits, node placement, and the
# "are the extra nodes earning accuracy" test.
source("/home/user/plant-dev/probes/40-lib.R")
node_steps <- function(sched, ode_times) sum(findInterval(ode_times, sched))
PSF <- c(height = 1.51, `birth-date` = 1.00)   # per-step factor, from the fixed-schedule decomposition

load_sweep <- function(f) {
  res <- readRDS(f)
  do.call(rbind, lapply(res, function(r) data.frame(
    model = r$model, arm = if (r$bd) "birth-date" else "height", eps = r$eps,
    iters = r$iters, converged = isTRUE(r$converged), n = r$n_run,
    steps = r$n_ode, node_steps = if (is.null(r$final)) NA else node_steps(r$final$times, r$final$ode_times),
    value = r$value, secs = r$total_s)))
}
files <- c(list.files("/home/user/plant-dev/probes/out", "^42-eps-.*rds$", full.names = TRUE),
           list.files("/home/user/plant-dev/probes/out", "^44-.*rds$", full.names = TRUE))
sw <- do.call(rbind, lapply(files, load_sweep))

fixed <- do.call(rbind, lapply(
  list.files("/home/user/plant-dev/probes/out", "^43-fixed-.*rds$", full.names = TRUE), readRDS))
fixed$arm <- ifelse(fixed$bd, "birth-date", "height")

cat("################ fixed-schedule convergence series ################\n")
lims <- list()
for (m in unique(fixed$model)) for (a in unique(fixed$arm)) {
  s <- fixed[fixed$model == m & fixed$arm == a & !is.na(fixed$value), ]
  if (nrow(s) < 2) next
  s <- s[order(s$k), ]
  d <- c(NA, diff(s$value)); rat <- c(NA, d[-1] / d[-length(d)]); p <- -log2(rat)
  rich <- s$value + d / (2^p - 1)
  print(data.frame(model = m, arm = a, k = s$k, n = s$n, steps = s$n_ode,
                   value = s$value, diff = d, ratio = rat, order = p,
                   richardson = rich), digits = 9, row.names = FALSE)
  v <- tail(rich[is.finite(rich)], 1)
  lims[[paste(m, a)]] <- if (length(v)) v else tail(s$value, 1)  # fall back to the finest run
  cat("\n")
}
print(unlist(lims), digits = 10)

cat("\n################ Pareto ################\n")
for (m in unique(sw$model)) {
  # reference limit: the birth-date arm's Richardson extrapolation (the two
  # coordinates must share a limit where growth depends on size alone; for TF24
  # the height arm's own series is reported separately).
  for (a in unique(sw$arm)) {
    V <- lims[[paste(m, a)]]
    Vb <- lims[[paste(m, "birth-date")]]
    s <- sw[sw$model == m & sw$arm == a, ]
    if (!nrow(s)) next
    s$relerr_own <- if (is.null(V)) NA else abs(s$value - V) / abs(V)
    s$relerr_bd  <- if (is.null(Vb)) NA else abs(s$value - Vb) / abs(Vb)
    s$cost <- s$steps * PSF[[a]]
    s$cost_ns <- s$node_steps * PSF[[a]]
    cat(sprintf("\n--- %s / %s   (own limit %s, birth-date limit %s) ---\n", m, a,
                format(V, digits = 10), format(Vb, digits = 10)))
    print(s[, c("eps","iters","converged","n","steps","node_steps","value",
                "relerr_own","relerr_bd","cost","cost_ns")], digits = 6, row.names = FALSE)
  }
}

cat("\n################ node placement (final adaptive schedule vs default) ################\n")
for (f in files) {
  for (r in readRDS(f)) {
    if (is.null(r$final)) next
    if (!(r$eps %in% c(0.02, 0.002))) next
    tt <- r$final$times
    d0 <- node_schedule_times_default(max(tt))
    br <- c(0, 0.1, 1, 5, 20, 60, 200)
    cat(sprintf("%-5s %-11s eps=%-8g n=%-4d  added by bin [0,.1](.1,1](1,5](5,20](20,60](60,+): %s   (default: %s)\n",
      r$model, if (r$bd) "bd" else "ht", r$eps, length(tt),
      paste(sprintf("%4d", table(cut(tt, br, include.lowest = TRUE)) -
                      table(cut(d0, br, include.lowest = TRUE))), collapse = " "),
      paste(sprintf("%4d", table(cut(d0, br, include.lowest = TRUE))), collapse = " ")))
  }
}

cat("\n################ adaptive vs uniform: does placement earn accuracy? ################\n")
for (f in files) {
  res <- readRDS(f)
  for (bd in unique(vapply(res, function(r) r$bd, logical(1)))) {
    rr <- Filter(function(r) identical(r$bd, bd), res)
    m <- rr[[1]]$model; a <- if (bd) "birth-date" else "height"
    V <- lims[[paste(m, a)]]; if (is.null(V)) next
    tr <- do.call(rbind, lapply(rr, function(r) r$trace))
    tr <- tr[tr$status == "ok", ]
    tr <- tr[!duplicated(tr$n_run), ]
    tr <- tr[order(tr$n_run), ]
    fx <- fixed[fixed$model == m & fixed$arm == a & !is.na(fixed$value), ]
    cat(sprintf("\n-- %s %s (limit %.10g) --\n adaptive: n:relerr\n  %s\n uniform : n:relerr\n  %s\n", m, a, V,
      paste(sprintf("%d:%.2e", tr$n_run, abs(tr$value - V)/abs(V)), collapse = "  "),
      paste(sprintf("%d:%.2e", fx$n, abs(fx$value - V)/abs(V)), collapse = "  ")))
  }
}
saveRDS(list(sw = sw, fixed = fixed, lims = lims), "/home/user/plant-dev/probes/out/48-report.rds")
