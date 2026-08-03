# Final assembly: convergence limits, the accuracy/cost Pareto, node placement,
# and the adaptive-vs-uniform placement test.
source("/home/user/plant-dev/probes/40-lib.R")
node_steps <- function(sched, ode) sum(findInterval(ode, sched))
PSF <- c(height = 1.51, `birth-date` = 1.00)  # measured per-step factor (fixed-schedule decomposition)

load_sweep <- function(f) {
  res <- readRDS(f)
  do.call(rbind, lapply(res, function(r) data.frame(
    model = r$model, arm = if (r$bd) "birth-date" else "height", eps = r$eps,
    iters = r$iters, conv = isTRUE(r$converged), n = r$n_run, steps = r$n_ode,
    node_steps = if (is.null(r$final)) NA_real_ else node_steps(r$final$times, r$final$ode_times),
    value = r$value, secs = r$total_s)))
}
files <- c(list.files("/home/user/plant-dev/probes/out", "^42-eps-TF24-(ht|bd)-3eps.rds$", full.names = TRUE),
           list.files("/home/user/plant-dev/probes/out", "^42-eps-TF24-(ht|bd)-extra.rds$", full.names = TRUE),
           list.files("/home/user/plant-dev/probes/out", "^44-.*rds$", full.names = TRUE))
sw <- do.call(rbind, lapply(files, load_sweep))
fixed <- do.call(rbind, lapply(
  list.files("/home/user/plant-dev/probes/out", "^43-fixed-.*rds$", full.names = TRUE), readRDS))
fixed$arm <- ifelse(fixed$bd, "birth-date", "height")

cat("############ 1. fixed-schedule convergence series (uniform bisection of the default) ############\n")
lims <- list()
for (m in unique(fixed$model)) for (a in c("height", "birth-date")) {
  s <- fixed[fixed$model == m & fixed$arm == a & !is.na(fixed$value), ]
  if (nrow(s) < 2) next
  s <- s[order(s$k), ]
  d <- c(NA, diff(s$value)); rat <- c(NA, d[-1] / d[-length(d)]); p <- -log2(rat)
  rich <- s$value + d / (2^p - 1)
  print(data.frame(model = m, arm = a, n = s$n, steps = s$n_ode, value = s$value,
                   diff = d, ratio = rat, order = p, richardson = rich),
        digits = 9, row.names = FALSE)
  v <- tail(rich[is.finite(rich)], 1)
  lims[[paste(m, a)]] <- if (length(v)) v else tail(s$value, 1)
  cat("\n")
}
cat("reference limits:\n"); print(unlist(lims), digits = 10)

cat("\n############ 2. accuracy / cost Pareto ############\n")
cat("cost_A = accepted ODE steps x per-step factor (the brief's proxy; valid only at equal node count)\n")
cat("cost_B = node-steps x per-step factor, node-steps = sum over accepted steps of the live node count\n")
for (m in unique(sw$model)) for (a in c("height", "birth-date")) {
  s <- sw[sw$model == m & sw$arm == a, ]
  if (!nrow(s)) next
  Vo <- lims[[paste(m, a)]]; Vb <- lims[[paste(m, "birth-date")]]
  s$relerr_own <- if (is.null(Vo)) NA else abs(s$value - Vo) / abs(Vo)
  s$relerr_bd  <- if (is.null(Vb)) NA else abs(s$value - Vb) / abs(Vb)
  s$cost_A <- s$steps * PSF[[a]]
  s$cost_B <- s$node_steps * PSF[[a]]
  cat(sprintf("\n-- %s / %s   own limit %s | birth-date limit %s --\n", m, a,
              format(Vo, digits = 10), format(Vb, digits = 10)))
  print(s[, c("eps","iters","conv","n","steps","node_steps","value","relerr_own","relerr_bd","cost_A","cost_B")],
        digits = 6, row.names = FALSE)
}

cat("\n############ 3. node placement: final adaptive schedule minus the default ############\n")
for (f in files) for (r in readRDS(f)) {
  if (is.null(r$final)) next
  tt <- r$final$times; d0 <- node_schedule_times_default(max(tt))
  br <- c(0, 0.1, 1, 5, 20, 60, 1e4)
  cat(sprintf("%-5s %-3s eps=%-9.3g n=%-4d  extra vs default per bin [0,.1] (.1,1] (1,5] (5,20] (20,60] (60,+): %s\n",
    r$model, if (r$bd) "bd" else "ht", r$eps, length(tt),
    paste(sprintf("%5d", table(cut(tt, br, include.lowest = TRUE)) -
                    table(cut(d0, br, include.lowest = TRUE))), collapse = " ")))
}
cat(sprintf("default schedule per bin: %s\n",
  paste(sprintf("%5d", table(cut(node_schedule_times_default(105.32),
                                 c(0,0.1,1,5,20,60,1e4), include.lowest = TRUE))), collapse = " ")))

cat("\n############ 4. do the adaptive placements earn accuracy? (relerr at matched node count) ############\n")
for (f in files) {
  res <- readRDS(f)
  for (bd in unique(vapply(res, function(r) r$bd, logical(1)))) {
    rr <- Filter(function(r) identical(r$bd, bd), res)
    m <- rr[[1]]$model; a <- if (bd) "birth-date" else "height"
    V <- lims[[paste(m, a)]]; if (is.null(V)) next
    tr <- do.call(rbind, lapply(rr, function(r) r$trace)); tr <- tr[tr$status == "ok", ]
    tr <- tr[!duplicated(tr$n_run), ]; tr <- tr[order(tr$n_run), ]
    fx <- fixed[fixed$model == m & fixed$arm == a & !is.na(fixed$value), ]
    cat(sprintf("\n-- %s %s (limit %.10g) --\n adaptive n:relerr  %s\n uniform  n:relerr  %s\n", m, a, V,
      paste(sprintf("%d:%.2e", tr$n_run, abs(tr$value - V)/abs(V)), collapse = " "),
      paste(sprintf("%d:%.2e", fx$n, abs(fx$value - V)/abs(V)), collapse = " ")))
  }
}
saveRDS(list(sw = sw, fixed = fixed, lims = lims), "/home/user/plant-dev/probes/out/48-report.rds")

cat("\n############ 5. matched-accuracy comparison (Pareto lower envelope) ############\n")
env_of <- function(s) {           # monotone lower envelope of (cost, relerr)
  s <- s[order(s$cost_B), ]; keep <- cummin(s$relerr) == s$relerr; s[keep, ]
}
for (m in unique(sw$model)) {
  Vb <- lims[[paste(m, "birth-date")]]
  tab <- list()
  for (a in c("height", "birth-date")) {
    s <- sw[sw$model == m & sw$arm == a, ]; if (!nrow(s)) next
    s$relerr <- abs(s$value - Vb) / abs(Vb)   # common reference: the birth-date limit
    s$cost_B <- s$node_steps * PSF[[a]]
    s$cost_A <- s$steps * PSF[[a]]
    tab[[a]] <- env_of(s[, c("arm","eps","n","steps","node_steps","value","relerr","cost_A","cost_B")])
  }
  cat(sprintf("\n== %s, error measured against the birth-date limit %.10g ==\n", m, Vb))
  print(do.call(rbind, tab), digits = 6, row.names = FALSE)
  if (length(tab) == 2) {
    for (tgt in c(1e-2, 3e-3, 1e-3, 3e-4, 1e-4)) {
      f <- function(z) { z <- z[z$relerr <= tgt, ]; if (nrow(z)) min(z$cost_B) else NA }
      ch <- f(tab$height); cb <- f(tab$`birth-date`)
      cat(sprintf("  target relerr %.0e:  height cost_B %-12s  birth-date cost_B %-12s  ratio %s\n",
                  tgt, format(ch, digits = 6), format(cb, digits = 6),
                  if (is.na(ch) || is.na(cb)) "n/a" else sprintf("%.2fx", ch / cb)))
    }
  }
}
