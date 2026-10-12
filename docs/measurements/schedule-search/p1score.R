# Phase 1 of plan-schedule-search.md: the per-quantity certificate on dy70 (late cap
# 70 d) against dy, with the three pass checks.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
src <- readLines("../placement/score.R"); eval(parse(text = src[1:grep("^fmt <-", src)]))
run <- function(name) { f <- file.path(D, "schedtest/adjmap/runs", paste0(name, ".rds")); if (file.exists(f)) readRDS(f) }
rd2 <- function(f) if (file.exists(f)) readRDS(f)
resq <- function(o) { x <- o$stand; e <- unname(x$elasticity); names(e) <- sub("^1\\.", "", names(x$elasticity))
  v <- c(`ln J` = log(x$J), e[!names(e) %in% structural]); names(v) <- paste("resident", names(v)); v }
pair <- function(m, f) { a <- resq(m); b <- resq(f); k <- intersect(names(a), names(b)); extrap(a[k], b[k]) }
refs <- list(episodic = pair(rd2(file.path(NR, "u429_episodic.rds")), rd2(file.path(P, "u857_episodic.rds"))),
  dry = pair(rd2(file.path(NR, "u215_dry.rds")), rd2(file.path(NR, "u429_dry.rds"))),
  `long-wet` = pair(rd2(file.path(NR, "u215_long-wet.rds")), rd2(file.path(NR, "u429_long-wet.rds"))),
  `long-drought` = pair(rd2(file.path(PF, "ld_D_u215.rds")), rd2(file.path(PF, "ld_D_u429.rds"))),
  lma = pair(rd2(file.path(D, "schedtest/placed2/runs/m_lma1252_episodic.rds")), rd2(file.path(D, "schedtest/placed2/runs/m_lma1254_episodic.rds"))))
nz <- function(x) if (is.numeric(x) && length(x) == 1) x else NA_real_
for (cs in list(c("dy", "episodic"), c("dy70", "episodic"), c("dy", "dry"), c("dy70", "dry"))) {
  h <- run(sprintf("hybl_%s_%s_p0", cs[1], cs[2])); cc <- run(sprintf("hyblC_%s_%s_p0", cs[1], cs[2])); if (is.null(cc$stand$elasticity) || is.null(h$stand$elasticity)) next
  ref <- refs[[cs[2]]]; qh <- resq(h); qc <- resq(cc)
  k <- Reduce(intersect, list(names(qh), names(qc), names(ref))); k <- k[!endsWith(k, nuisance)]
  err <- (qh[k] - ref[k]) / eps_vec(k); est <- (qc[k] - qh[k]) / 3 / eps_vec(k); ex <- err + (qh[k] - qc[k]) / 3 / eps_vec(k)
  big <- abs(err) > 1 / 3; ok <- abs(est / err) >= 0.5 & abs(est / err) <= 2 & sign(est) == sign(err)
  over <- abs(err) > 1; rp <- "resident root_P50"
  c1 <- all(abs(est[over]) > 0.5); c2 <- mean(ok[big]) >= 0.8 && (!big[rp] || ok[rp]); c3 <- all(abs(ex) <= 1)
  cat(sprintf("%-5s %-9s nodes H %d C %d, cpu H %.0f+%.0f s | over eps %d, flagged %d [%s] | x2 %d of %d (%.0f%%), root_P50 err %+.2f est %+.2f [%s] | extrapolated worst %.2f [%s] | H worst %.2f\n",
    cs[1], cs[2], length(h$node_times), length(cc$node_times), nz(h$stand$cpu), nz(h$sweep_cpu), sum(over), sum(over & abs(est) > 0.5), if (c1) "ok" else "FAIL", sum(ok[big]), sum(big), 100 * mean(ok[big]),
    err[rp], est[rp], if (c2) "ok" else "FAIL", max(abs(ex)), if (c3) "ok" else "FAIL", max(abs(err))))
  w <- order(-abs(err))[1:5]; print(data.frame(q = sub("resident ", "", k[w]), err = round(err[w], 2), est = round(est[w], 2), extrap = round(ex[w], 2)), row.names = FALSE) }
