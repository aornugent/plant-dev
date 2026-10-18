# fr_screen.R: the offline screen. Each configuration as it would have run on the saved runs
# (fr_data.R): true error of its answer, its estimate and bound, coverage and CPU. eps units.
SP <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"
FR <- readRDS(file.path(SP, "frontier/fr_data.rds"))
U_REP <- 0.33; U_PAIR <- 0.19; R_MIN <- 0.82
# A configuration on one case: answer error `err`, estimate `e`, bound vector `b`, CPU `cpu`.
cfg <- function(err, e, b, cpu) list(err = err, e = e, b = b, cpu = cpu)
plain <- function(err, e, u) cfg(err, e, abs(e) / R_MIN + u, NA)
# Corrected answer Q - e: residual (1 - read) err + short spells + tolerance; bound beta |e| + u.
corrected <- function(err, e, u, beta) cfg(err - e, e, beta * abs(e) + u, NA)

configs <- function(z, beta = 0.5) {
  s1 <- z$s1; r5 <- z$r5; L <- z$s05$levels; rp <- z$s05$replay; f05 <- z$s05$first_cpu
  e05 <- (rp$err - L[[1]]$err) / 3; e01 <- (L[[1]]$err - L[[2]]$err) / 3
  out <- list(
    K0_canonical = plain(s1$err, s1$e, U_REP),
    K0r_round5 = plain(r5$err, r5$e, U_REP),
    K1_corrected_s1 = corrected(s1$err, s1$e, U_REP, beta),
    K2_corrected_s05 = corrected(L[[1]]$err, e05, U_REP, beta),
    K2p_plain_s05 = plain(L[[1]]$err, e05, U_REP),
    K3_pair_s05 = plain(L[[2]]$err, e01, U_PAIR),
    K4_pair_s05_corrected = corrected(L[[2]]$err, e01, U_PAIR, beta))
  out$K0_canonical$cpu <- sum(s1$cpu); out$K0r_round5$cpu <- sum(r5$cpu) + s1$cpu[["first"]]
  out$K1_corrected_s1$cpu <- sum(s1$cpu)
  out$K2_corrected_s05$cpu <- out$K2p_plain_s05$cpu <- f05 + L[[1]]$cpu + rp$cpu
  out$K3_pair_s05$cpu <- out$K4_pair_s05_corrected$cpu <- f05 + L[[1]]$cpu + L[[2]]$cpu
  if (length(L) > 2) { e12 <- (L[[2]]$err - L[[3]]$err) / 3
    out$K5_pair_l12 <- plain(L[[3]]$err, e12, U_PAIR); out$K5_pair_l12$cpu <- f05 + L[[1]]$cpu + L[[2]]$cpu + L[[3]]$cpu }
  out }
summ <- function(k, cs, x, base) data.frame(config = k, case = cs, worst = max(abs(x$err)), q = names(x$err)[which.max(abs(x$err))],
  rms = sqrt(mean(x$err^2)), bound_max = max(x$b), accept = all(x$b < 1), covered = sum(abs(x$err) <= x$b), miss_by = max(abs(x$err) - x$b),
  cpu = x$cpu, cpu_rel = x$cpu / base)
tab <- do.call(rbind, lapply(names(FR), function(cs) { z <- FR[[cs]]; cc <- configs(z); base <- cc$K0_canonical$cpu
  do.call(rbind, lapply(names(cc), function(k) summ(k, cs, cc[[k]], base))) }))
options(width = 200); print(format(tab, digits = 3), row.names = FALSE)

# The corrected answer's residual against |e|: what beta and u an honest bound needs, per case
# and pooled over both scales (s1 replay, s05 replay, s05 pair), with the short spells' share.
cat("\nResidual |err - e| of the corrected answer: largest per case and source, and the beta each needs at u\n")
res <- do.call(rbind, lapply(names(FR), function(cs) { z <- FR[[cs]]; L <- z$s05$levels
  src <- list(s1 = list(err = z$s1$err, e = z$s1$e, u = U_REP), r5 = list(err = z$r5$err, e = z$r5$e, u = U_REP),
              s05 = list(err = L[[1]]$err, e = (z$s05$replay$err - L[[1]]$err) / 3, u = U_REP),
              pair05 = list(err = L[[2]]$err, e = (L[[1]]$err - L[[2]]$err) / 3, u = U_PAIR))
  if (length(L) > 2) src$pair12 <- list(err = L[[3]]$err, e = (L[[2]]$err - L[[3]]$err) / 3, u = U_PAIR)
  do.call(rbind, lapply(names(src), function(s) { a <- src[[s]]; r <- abs(a$err - a$e)
    data.frame(case = cs, source = s, worst_err = max(abs(a$err)), worst_resid = max(r), q = names(r)[which.max(r)],
      rms_resid = sqrt(mean(r^2)), beta_needed = max(0, max((r - a$u) / abs(a$e))), e_max = max(abs(a$e)),
      read_min = { k <- abs(a$err) > 0.2; if (any(k)) min(a$e[k] / a$err[k]) else NA }) })) }))
print(format(res, digits = 3), row.names = FALSE)
saveRDS(list(tab = tab, res = res), file.path(SP, "frontier/fr_screen.rds"))
