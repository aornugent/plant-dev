# Task 1's scores for plant's forward runs (harness/run_record.R with the soil record) at
# each soil weight and tolerance, with round one's driver runs for x10 and x100 beside them:
# accepted steps, rows (the members on each accepted step), the forward's member
# evaluations (each attempt's six evaluations at the step's members, and one at each
# entry), a gradient run's cost against the CK baseline at 3e-5 ((forward + 6 rows) / 7),
# e_J and the soil's errors against the tight recording; then the convergence test.
#   Rscript score_t1.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1a")
JSTAR <- 12.6687135
ref <- readRDS(file.path(D, "partition_bias/out/rec_1e-7.rds"))
base <- readRDS(file.path(D, "seed/tied_3e-5.rds"))
brows <- sum(as.numeric(base$st$M)); bfwd <- base$counts$members
soil_err <- function(time, theta) {
  # plant's trajectory holds a state twice at each introduction and pulse; the soil is
  # the same in both, so one is kept.
  keep <- !duplicated(time, fromLast = TRUE)
  time <- time[keep]; theta <- theta[keep, , drop = FALSE]
  i <- match(time, ref$time); ok <- which(!is.na(i))
  d <- abs(theta[ok, , drop = FALSE] - ref$soil[i[ok], ])
  c(max = max(d), med = median(apply(d, 1, max)), common = length(ok))
}
plant_row <- function(name, f) {
  r <- readRDS(f); s <- r$stand
  t <- s$times; nt <- r$node_times
  M <- findInterval(t[-length(t)], nt)          # members on each step, from its start
  # plant reports its attempts by outcome (accepted first), not per step, so a rejected
  # attempt is charged the accepted steps' mean members; on the driver's ck10_3e-5 this
  # rule gives 5 692 104 against the counted 5 700 178 (-0.14%).
  att <- s$attempts
  rej <- sum(att) - att[1] - att[2]
  fwd <- 6 * sum(as.numeric(M)) * (1 + rej / length(M)) + sum(seq_along(nt))
  se <- if (!is.null(s$soil)) soil_err(s$soil$time, s$soil$theta) else c(max = NA, med = NA, common = NA)
  data.frame(run = name, accepted = length(M), rows = sum(as.numeric(M)), forward = fwd,
             e_J = s$J / JSTAR - 1, soil_max = se[["max"]], soil_med = se[["med"]], common = se[["common"]])
}
driver_row <- function(name, f) {
  r <- readRDS(f); st <- r$st
  se <- soil_err(st$time, as.matrix(st[, paste0("soil_", 1:5)]))
  data.frame(run = name, accepted = nrow(st), rows = sum(as.numeric(st$M)), forward = r$counts$members,
             e_J = r$J / JSTAR - 1, soil_max = se[["max"]], soil_med = se[["med"]], common = se[["common"]])
}
rows <- list(
  driver_row("x1 (base) 1e-4", file.path(D, "split/out/mono_1e-4.rds")),
  driver_row("x1 (base) 3e-5", file.path(D, "seed/tied_3e-5.rds")),
  driver_row("x1 (base) 1e-5", file.path(D, "rej/tied_1e-5_soil1.rds")),
  driver_row("x10 (ck10) 1e-4", file.path(P, "runs/ck10_1e-4.rds")),
  driver_row("x10 (ck10) 3e-5", file.path(P, "runs/ck10_3e-5.rds")),
  driver_row("x10 (ck10) 1e-5", file.path(D, "rej/tied_1e-5_soil10.rds")))
for (w in c(10, 20, 30, 50)) for (tol in c("1e-4", "3e-5", "1e-5")) {
  f <- file.path(P, "t1/runs", sprintf("w%d_%s.rds", w, tol))
  if (file.exists(f) && !is.null(readRDS(f)$stand$J)) rows[[length(rows) + 1]] <- plant_row(sprintf("x%d (plant) %s", w, tol), f)
}
rows <- c(rows, list(driver_row("x100 (ck100a) 1e-4", file.path(P, "runs/ck100a_1e-4.rds")),
                     driver_row("x100 (ck100) 3e-5", file.path(P, "runs/ck100_3e-5.rds")),
                     driver_row("x100 (ck100a) 1e-5", file.path(P, "runs/ck100a_1e-5.rds"))))
s <- do.call(rbind, rows)
s$rows_rel <- sprintf("%+.1f%%", 100 * (s$rows / brows - 1))
s$gradient_rel <- sprintf("%+.1f%%", 100 * ((s$forward / bfwd + 6 * s$rows / brows) / 7 - 1))
s$lnJ_eps <- sprintf("%.4f", abs(log1p(s$e_J)) / 0.0252373)
out <- within(s, { e_J <- sprintf("%+.2e", e_J); soil_max <- sprintf("%.2e", soil_max); soil_med <- sprintf("%.2e", soil_med) })
options(width = 200)
print(out[, c("run", "accepted", "rows", "forward", "rows_rel", "gradient_rel", "e_J", "lnJ_eps", "soil_max", "soil_med", "common")], row.names = FALSE)
saveRDS(s, file.path(P, "t1/score_t1.rds"))
conv <- function(x, floor) {
  if (length(x) < 3 || anyNA(x)) return(NA)
  abs(x[3]) <= max(abs(x[1]) / 3, floor) && abs(x[2]) <= 1.5 * max(abs(x[1]), floor)
}
cat("\nconvergence over 1e-4, 3e-5, 1e-5 (round one's test):\n")
s$weight <- sub(" .*", "", s$run); s$tol <- sub(".* ", "", s$run)
for (w in unique(s$weight)) {
  x <- s[s$weight == w, ]; x <- x[match(c("1e-4", "3e-5", "1e-5"), x$tol), ]
  cat(sprintf("  %-5s e_J %s [%s]  soil_max %s [%s]  soil_med %s [%s]\n", w,
              paste(sprintf("%+.2e", x$e_J), collapse = " "), conv(x$e_J, 6e-6),
              paste(sprintf("%.2e", x$soil_max), collapse = " "), conv(x$soil_max, 0),
              paste(sprintf("%.2e", x$soil_med), collapse = " "), conv(x$soil_med, 0)))
}
