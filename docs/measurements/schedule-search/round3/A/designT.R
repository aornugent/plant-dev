# T on the training five for a09's two schedules with the committed run at tol_c and the
# check at tol_k, from the saved runs' rows. Rows at a tolerance between 1e-4 and 3e-4
# are interpolated in log tol from each schedule's own pair (a09 at 1e-4, a09h at 3e-4);
# a schedule without its 3e-4 run takes the median ratio of those that have one.
# Decisions are a09's (coarse on four, fine on episodic-lma) unless DECIDE gives others.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
rw <- function(tag, r, case) { f <- file.path(AR, sprintf("val_%s_%s_%s.rds", tag, r, case)); if (file.exists(f)) readRDS(f)$stand$rows else NA }
cases <- names(CASES)
R <- do.call(rbind, lapply(cases, function(cs) data.frame(case = cs, c4 = rw("a09", "c", cs), c3 = rw("a09h", "c", cs), f4 = rw("a09", "f", cs), f3 = rw("a09h", "f", cs))))
ratio <- median(c(R$c3 / R$c4, R$f3 / R$f4), na.rm = TRUE); a <- -log(ratio) / log(3)
cat(sprintf("rows at 3e-4 over 1e-4: %s; median %.3f, so rows ~ tol^-%.3f\n", paste(sprintf("%.3f", na.omit(c(R$c3 / R$c4, R$f3 / R$f4))), collapse = " "), ratio, a))
R$c3[is.na(R$c3)] <- R$c4[is.na(R$c3)] * ratio; R$f3[is.na(R$f3)] <- R$f4[is.na(R$f3)] * ratio
at <- function(r4, r3, t) r4 * exp(log(r3 / r4) * log(t / 1e-4) / log(3))
fine <- c(`episodic-lma` = TRUE)
Tof <- function(tc, tk, decide = fine) sum(sapply(seq_len(nrow(R)), function(i) { cs <- R$case[i]; rc <- at(R$c4[i], R$c3[i], tc); rk <- at(R$f4[i], R$f3[i], tk)
  use <- if (isTRUE(decide[cs])) rk else rc; run_cost(rc) + run_cost(rk) + 2 * run_cost(use) }))
s <- 0.40
cat(sprintf("a09, 1e-4 / 1e-4: T %.0f\n", Tof(1e-4, 1e-4)))
cat(sprintf("a09h, 3e-4 / 3e-4: T %.0f\n", Tof(3e-4, 3e-4)))
for (p in c(0.5, 0.7, 1, 2, 3)) { tk <- 3e-4 * s^(1 / p)
  cat(sprintf("matched, commit 3e-4, check 3e-4 * %.2f^(1/%.1f) = %.2e: T %.0f (if dry also commits fine: %.0f)\n", s, p, tk, Tof(3e-4, tk), Tof(3e-4, tk, c(fine, dry = TRUE)))) }
cat(sprintf("commit 3e-4, check 1e-4: T %.0f (dry fine: %.0f)\n", Tof(3e-4, 1e-4), Tof(3e-4, 1e-4, c(fine, dry = TRUE))))
for (t in c(1.5e-4, 2e-4)) cat(sprintf("both at %.1e: T %.0f\n", t, Tof(t, t)))
