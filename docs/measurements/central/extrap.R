# Per-quantity certificate: (C - H)/3 against H's error from the reference, for every
# resident quantity, on each hybrid loop's pass-0 schedule.
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
for (cs in list(c("dy", "episodic"), c("dy", "dry"), c("dy", "long-wet"), c("dy", "long-drought"), c("dylma", "episodic"))) {
  h <- run(sprintf("hybl_%s_%s_p0", cs[1], cs[2])); cc <- run(sprintf("hyblC_%s_%s_p0", cs[1], cs[2])); if (is.null(cc$stand$elasticity)) next
  ref <- refs[[if (cs[1] == "dylma") "lma" else cs[2]]]; qh <- resq(h); qc <- resq(cc)
  k <- Reduce(intersect, list(names(qh), names(qc), names(ref))); k <- k[!endsWith(k, nuisance)]
  err <- (qh[k] - ref[k]) / eps_vec(k); est <- (qc[k] - qh[k]) / 3 / eps_vec(k); ex <- err - est
  cat(sprintf("%-6s %-12s: H worst %.2f, median %.3f, over eps %d | H + (H - C)/3 worst %.2f, median %.3f, over eps %d\n", cs[1], cs[2],
    max(abs(err)), median(abs(err)), sum(abs(err) > 1), max(abs(ex)), median(abs(ex)), sum(abs(ex) > 1))) }
