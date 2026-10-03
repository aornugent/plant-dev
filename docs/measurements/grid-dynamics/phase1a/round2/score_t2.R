# Task 2's scores: ARK with the soil weighted x100 under the chain alone's soil estimate
# (arkc), against round one's ark100 (the pair's embedded estimate) and the CK baseline:
# rows, forward, a gradient run's cost against DEV/seed/tied_3e-5.rds, e_J, the soil's
# errors against the tight recording, binding components; the convergence test; and, per
# accepted step, the two soil estimates side by side.
#   Rscript score_t2.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1a")
JSTAR <- 12.6687135
ref <- readRDS(file.path(D, "partition_bias/out/rec_1e-7.rds"))
base <- readRDS(file.path(D, "seed/tied_3e-5.rds"))
brows <- sum(as.numeric(base$st$M)); bfwd <- base$counts$members
NODE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
          "storage", "offspring", "log_density", "mass")
ENV <- c(paste0("soil_", 1:5), paste0("accumulator_", 1:5))
row <- function(name, f) {
  r <- readRDS(f); st <- r$st
  i <- match(st$time, ref$time); ok <- which(!is.na(i))
  d <- abs(as.matrix(st[ok, paste0("soil_", 1:5)]) - ref$soil[i[ok], ])
  kind <- ifelse(st$ei <= 9 * st$M, NODE[(st$ei - 1) %% 9 + 1], ENV[pmax(1, st$ei - 9 * st$M)])
  rows <- sum(as.numeric(st$M)); fwd <- r$counts$members
  rej <- sum(unlist(r$attempts[c("rejected_inaccurate", "rejected_thrown", "rejected_refused")]))
  data.frame(run = name, tol = r$tol, accepted = nrow(st), rejected = rej, rows = rows, forward = fwd,
             gradient_rel = (fwd / bfwd + 6 * rows / brows) / 7 - 1, e_J = r$J / JSTAR - 1,
             soil_max = max(d), soil_med = median(apply(d, 1, max)),
             bind = sprintf("%.0f/%.1f/%.0f", 100 * mean(grepl("^soil_", kind)), 100 * mean(grepl("^acc", kind)),
                            100 * mean(kind %in% NODE)),
             secs = r$secs, chain_substeps = if (is.null(r$counts$chain_substeps)) NA else r$counts$chain_substeps)
}
f <- c(`ark100 1e-4` = file.path(P, "runs/ark100_1e-4.rds"), `ark100 3e-5` = file.path(P, "runs/ark100_3e-5.rds"),
       `ark100 1e-5` = file.path(P, "runs/ark100_1e-5.rds"))
for (t in c("1e-4", "3e-5", "1e-5", "2.85e-5", "3.15e-5")) {
  g <- file.path(P, "t2/runs", sprintf("arkc_%s.rds", t))
  if (file.exists(g)) f[[sprintf("arkc %s", t)]] <- g
}
s <- do.call(rbind, Map(row, names(f), f))
out <- within(s, { gradient_rel <- sprintf("%+.1f%%", 100 * gradient_rel); e_J <- sprintf("%+.2e", e_J)
  soil_max <- sprintf("%.2e", soil_max); soil_med <- sprintf("%.2e", soil_med)
  lnJ_eps <- sprintf("%.3f", abs(log1p(as.numeric(e_J))) / 0.0252373) })
options(width = 200)
print(out[, c("run", "accepted", "rejected", "rows", "forward", "gradient_rel", "e_J", "lnJ_eps", "soil_max", "soil_med", "bind", "secs", "chain_substeps")], row.names = FALSE)
conv <- function(x, floor) {
  if (length(x) < 3 || anyNA(x)) return(NA)
  abs(x[3]) <= max(abs(x[1]) / 3, floor) && abs(x[2]) <= 1.5 * max(abs(x[1]), floor)
}
cat("\nconvergence over 1e-4, 3e-5, 1e-5 (round one's test):\n")
for (v in c("ark100", "arkc")) {
  x <- s[sub(" .*", "", s$run) == v, ]; x <- x[match(c(1e-4, 3e-5, 1e-5), x$tol), ]
  cat(sprintf("  %-7s e_J %s [%s]  soil_max %s [%s]  soil_med %s [%s]\n", v,
              paste(sprintf("%+.2e", x$e_J), collapse = " "), conv(x$e_J, 6e-6),
              paste(sprintf("%.2e", x$soil_max), collapse = " "), conv(x$soil_max, 0),
              paste(sprintf("%.2e", x$soil_med), collapse = " "), conv(x$soil_med, 0)))
}
cat("\nthe two soil estimates on arkc's accepted steps (largest layer each): chain / embedded\n")
for (n in grep("^arkc", names(f), value = TRUE)) {
  e <- readRDS(f[[n]])$soil_est
  q <- e[, "chain"] / e[, "embedded"]
  cat(sprintf("  %-12s median %.3g, 10%% %.3g, 90%% %.3g; chain larger on %.1f%% of steps\n", n,
              median(q, na.rm = TRUE), quantile(q, 0.1, na.rm = TRUE), quantile(q, 0.9, na.rm = TRUE),
              100 * mean(q > 1, na.rm = TRUE)))
}
saveRDS(s, file.path(P, "t2/score_t2.rds"))

# The constant record (150-node resolved grid) at each variant's working tolerance, against
# the CK baseline at 3e-5 there; J* = 289.2738962.
cat("\nconstant record:\n")
cb <- readRDS(file.path(D, "pi/runs/const_base_3e-5.rds")); cbr <- sum(as.numeric(cb$st$M))
for (g in c(file.path(D, "pi/runs/const_base_3e-5.rds"), file.path(P, "runs/const_ck10_3e-5.rds"),
            file.path(P, "runs/const_ark100_1e-5.rds"), file.path(P, "t2/runs/const_arkc_3e-5.rds"))) {
  r <- readRDS(g); rows <- sum(as.numeric(r$st$M))
  cat(sprintf("  %-22s accepted %5d rows %7.0f forward %8.0f gradient run %+6.1f%% e_J %+.2e\n", basename(g), nrow(r$st),
              rows, r$counts$members, 100 * ((r$counts$members / cb$counts$members + 6 * rows / cbr) / 7 - 1), r$J / 289.2738962 - 1))
}
