# Invaders on the hybrid schedules: each quantity's error on H against the reference
# (resident and invader), the certificate (C - H)/3, and the extrapolation H + (H - C)/3.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
src <- readLines("../placement/score.R"); eval(parse(text = src[1:grep("^fmt <-", src)]))
Q <- file.path(D, "schedtest/placed2/runs"); rd2 <- function(f) if (file.exists(f)) readRDS(f)
pair2 <- function(m, f) { a <- quantities(m); b <- quantities(f); k <- intersect(names(a), names(b)); extrap(a[k], b[k]) }
refs <- list(episodic = pair2(rd2(file.path(NR, "u429_episodic.rds")), rd2(file.path(P, "u857_episodic.rds"))),
  dry = pair2(rd2(file.path(NR, "u215_dry.rds")), rd2(file.path(NR, "u429_dry.rds"))),
  `long-wet` = pair2(rd2(file.path(NR, "u215_long-wet.rds")), rd2(file.path(NR, "u429_long-wet.rds"))),
  `long-drought` = pair2(rd2(file.path(PF, "ld_D_u215.rds")), rd2(file.path(PF, "ld_D_u429.rds"))),
  lma = pair2(rd2(file.path(Q, "m_lma1252_episodic.rds")), rd2(file.path(Q, "m_lma1254_episodic.rds"))))
for (cs in list(c("dy", "episodic"), c("dy", "dry"), c("dy", "long-wet"), c("dy", "long-drought"), c("dylma", "episodic"))) {
  h <- rd2(file.path(Q, sprintf("inv_H_%s_%s.rds", cs[1], cs[2]))); cc <- rd2(file.path(Q, sprintf("inv_C_%s_%s.rds", cs[1], cs[2])))
  if (is.null(h) || is.null(cc)) next; qh <- quantities(h); qc <- quantities(cc); if (is.null(qh) || is.null(qc)) { cat(cs, "incomplete\n"); next }
  ref <- refs[[if (cs[1] == "dylma") "lma" else cs[2]]]
  k <- Reduce(intersect, list(names(qh), names(qc), names(ref))); k <- k[!endsWith(k, nuisance)]
  err <- (qh[k] - ref[k]) / eps_vec(k); est <- (qc[k] - qh[k]) / 3 / eps_vec(k); ex <- err - est
  for (role in c("resident", "invader")) { r <- startsWith(k, role); big <- r & abs(err) > 1 / 3
    ok <- abs(est[big] / err[big]) >= 0.5 & abs(est[big] / err[big]) <= 2 & sign(est[big]) == sign(err[big])
    cat(sprintf("%-6s %-12s %-8s: H worst %.2f median %.3f over eps %2d | flagged %d of %d | within x2 %d of %d | corr %.2f | extrapolated worst %.2f median %.3f over eps %d\n",
      cs[1], cs[2], role, max(abs(err[r])), median(abs(err[r])), sum(abs(err[r]) > 1), sum(r & abs(err) > 1 & abs(est) > 0.5), sum(r & abs(err) > 1), sum(ok), sum(big),
      cor(err[r], est[r]), max(abs(ex[r])), median(abs(ex[r])), sum(abs(ex[r]) > 1))) } }
