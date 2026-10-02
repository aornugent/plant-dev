# Task 5: the chain alone's global moisture error against tol, from chain_ladder.sh's OUT
# files: on long drought at the knots, on constant at the end and at the OBS times.
C <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi/chain"
cols <- paste0("theta_", 1:5)
tols <- c("1e-3", "3e-4", "1e-4", "3e-5", "1e-5", "3e-6", "1e-6", "3e-7", "1e-7")
OBS <- c(0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 30)
at_times <- function(x, ref, times) {
  i <- match(times, x$rows[, "t0"]); j <- match(times, ref$rows[, "t0"])
  ok <- !is.na(i) & !is.na(j)
  e <- x$rows[i[ok], cols, drop = FALSE] / ref$rows[j[ok], cols, drop = FALSE] - 1
  rownames(e) <- times[ok]
  e
}
summ <- function(e) c(median = median(abs(e)), rms = sqrt(mean(e^2)), max = max(abs(e)), mean = mean(e))
rd <- function(f) readRDS(file.path(C, f))
ref_ld <- rd("ref_ld.rds"); ref_c <- rd("ref_const.rds"); refo <- rd("refobs_const.rds")
knots <- readRDS(file.path(dirname(dirname(C)), "seed", "tied_3e-5.rds"))$knots
knots <- knots[knots > 0 & knots < 40]
# the reference's own error: pi at 1e-10 against odelia at 1e-10
cat(sprintf("reference check, pi 1e-10 against odelia 1e-10: long drought at the knots max %.2g; constant end %.2g, at the OBS times max %.2g\n",
            max(abs(at_times(rd("refpi_ld.rds"), ref_ld, knots))),
            max(abs(rd("refpi_const.rds")$y / ref_c$y - 1)),
            max(abs(at_times(rd("refobspi_const.rds"), refo, OBS)))))
out <- list()
for (law in c("odelia", "pi")) for (tol in tols) {
  ld <- rd(sprintf("lad_ld_%s_%s.rds", law, tol))
  co <- rd(sprintf("lad_const_%s_%s.rds", law, tol))
  ob <- rd(sprintf("obs_const_%s_%s.rds", law, tol))
  e_ld <- at_times(ld, ref_ld, knots)
  e_end_ld <- ld$y / ref_ld$y - 1
  e_c <- co$y / ref_c$y - 1
  e_o <- at_times(ob, refo, OBS)
  out[[length(out) + 1]] <- data.frame(
    law, tol = as.numeric(tol), ld_steps = nrow(ld$rows), ld_rej = ld$rejected,
    ld_med = median(abs(e_ld)), ld_rms = sqrt(mean(e_ld^2)), ld_max = max(abs(e_ld)), ld_mean1 = mean(e_ld[, 1]),
    ld_end = max(abs(e_end_ld)),
    c_steps = nrow(co$rows), c_rej = co$rejected, c_end = max(abs(e_c)), c_end_signed = e_c[5],
    c_obs_n = nrow(e_o), c_obs_early = max(abs(e_o[as.numeric(rownames(e_o)) <= 0.5, ])),
    c_obs_late = max(abs(e_o[as.numeric(rownames(e_o)) >= 2, ])))
}
d <- do.call(rbind, out)
fmt <- function(x) formatC(x, digits = 2, format = "g")
for (law in c("odelia", "pi")) {
  x <- d[d$law == law, ]
  cat(sprintf("\n== %s\n", law))
  cat(sprintf("%-6s %6s %5s | %8s %8s %8s %6s %6s | %8s | %5s %4s %8s %8s %8s\n", "tol", "steps", "rej", "ld med", "med/tol",
              "ld max", "max/tol", "slope", "ld end", "c st", "c rj", "c end", "c early", "c late"))
  for (i in seq_len(nrow(x))) {
    sl <- if (i > 1) log(x$ld_med[i] / x$ld_med[i - 1]) / log(x$tol[i] / x$tol[i - 1]) else NA
    cat(sprintf("%-6g %6d %5d | %8s %8.3f %8s %6.2f %6s | %8s | %5d %4d %8s %8s %8s\n", x$tol[i], x$ld_steps[i], x$ld_rej[i],
                fmt(x$ld_med[i]), x$ld_med[i] / x$tol[i], fmt(x$ld_max[i]), x$ld_max[i] / x$tol[i],
                if (is.na(sl)) "" else sprintf("%.2f", sl), fmt(x$ld_end[i]), x$c_steps[i], x$c_rej[i],
                fmt(x$c_end[i]), fmt(x$c_obs_early[i]), fmt(x$c_obs_late[i])))
  }
}
saveRDS(d, file.path(C, "chain_prop.rds"))
